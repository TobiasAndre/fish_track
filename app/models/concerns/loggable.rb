module Loggable
  extend ActiveSupport::Concern

  included do
    before_destroy :capture_activity_snapshot
    after_commit :log_activity, on: %i[create update destroy]
  end

  private

  def capture_activity_snapshot
    @activity_snapshot = activity_description
  end

  def log_activity
    return unless Current.user

    ActivityLog.record!(
      user: Current.user,
      action: activity_action,
      resource_type: self.class.name,
      resource_id: id,
      event_type: activity_event_type,
      description: @activity_snapshot || activity_description
    )
  end

  def activity_action
    return "destroy" if destroyed?

    previously_new_record? ? "create" : "update"
  end

  def activity_event_type
    nil
  end
end
