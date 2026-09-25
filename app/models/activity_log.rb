class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :company, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true
  validates :description, presence: true

  ACTIONS = %w[create update destroy].freeze

  scope :recent_first, -> { order(created_at: :desc) }

  Change = Struct.new(:field, :before, :after, keyword_init: true)

  def self.record!(user:, action:, resource_type:, description:, resource_id: nil, event_type: nil, company: Current.company, ip_address: Current.ip_address,
                   object_before: nil, object_after: nil)
    create!(
      user: user,
      company: company,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      event_type: event_type,
      description: description,
      ip_address: ip_address,
      object_before: object_before,
      object_after: object_after
    )
  end

  # Logs antigos (anteriores à gravação do antes/depois) não têm o objeto.
  def snapshot?
    object_before.present? || object_after.present?
  end

  # O que mudou, campo a campo. Na criação lista todos os campos gravados e na
  # exclusão todos os que existiam; na atualização, só os que mudaram.
  def field_changes
    before = object_before || {}
    after = object_after || {}

    (before.keys | after.keys).filter_map do |field|
      next if action == "update" && (before[field] == after[field] || field == "updated_at")

      Change.new(field: field, before: before[field], after: after[field])
    end
  end

  def human_action
    I18n.t("activity_logs.actions.#{action}", default: action)
  end
end
