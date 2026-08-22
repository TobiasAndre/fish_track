class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :company, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true
  validates :description, presence: true

  ACTIONS = %w[create update destroy].freeze

  scope :recent_first, -> { order(created_at: :desc) }

  def self.record!(user:, action:, resource_type:, description:, resource_id: nil, event_type: nil, company: Current.company, ip_address: Current.ip_address)
    create!(
      user: user,
      company: company,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      event_type: event_type,
      description: description,
      ip_address: ip_address
    )
  end

  def human_action
    I18n.t("activity_logs.actions.#{action}", default: action)
  end
end
