module Loggable
  extend ActiveSupport::Concern

  # Campos que nunca vão para o log (senhas, tokens, segredos).
  SENSITIVE_ATTRIBUTE = /password|token|secret|otp/i
  FILTERED = "[FILTERED]".freeze

  included do
    before_destroy :capture_activity_snapshot
    after_commit :log_activity, on: %i[create update destroy]
  end

  private

  def capture_activity_snapshot
    @activity_snapshot = activity_description
    @activity_destroyed_object = loggable_attributes(attributes)
  end

  def log_activity
    return unless Current.user

    ActivityLog.record!(
      user: Current.user,
      action: activity_action,
      resource_type: self.class.name,
      resource_id: id,
      event_type: activity_event_type,
      description: @activity_snapshot || activity_description,
      object_before: activity_object_before,
      object_after: activity_object_after
    )
  end

  def activity_action
    return "destroy" if destroyed?

    previously_new_record? ? "create" : "update"
  end

  def activity_event_type
    nil
  end

  # Estado do objeto antes da ação: nada na criação; o registro que existia na
  # exclusão; e, na atualização, os valores anteriores de quem mudou.
  def activity_object_before
    case activity_action
    when "create" then nil
    when "destroy" then @activity_destroyed_object
    else loggable_attributes(attributes.merge(saved_changes.transform_values(&:first)))
    end
  end

  # Estado depois da ação: nada na exclusão.
  def activity_object_after
    activity_action == "destroy" ? nil : loggable_attributes(attributes)
  end

  def loggable_attributes(hash)
    hash.as_json.to_h do |name, value|
      [name, value.present? && name.match?(SENSITIVE_ATTRIBUTE) ? FILTERED : value]
    end
  end
end
