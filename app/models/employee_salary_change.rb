class EmployeeSalaryChange < ApplicationRecord
  belongs_to :employee

  # users live in the public schema, not the tenant schema this record lives
  # in (see Profile#user_id) -- there's no real FK, association is best-effort.
  belongs_to :created_by, class_name: "User", optional: true

  CHANGE_TYPES = %w[initial adjustment promotion correction other].freeze

  validates :salary_cents, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :previous_salary_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :effective_on, presence: true
  validates :change_type, presence: true, inclusion: { in: CHANGE_TYPES }

  scope :recent_first, -> { order(effective_on: :desc, created_at: :desc) }

  def human_change_type
    I18n.t("enums.employee_salary_change.change_type.#{change_type}", default: change_type.to_s)
  end
end
