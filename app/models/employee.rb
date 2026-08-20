class Employee < ApplicationRecord
  belongs_to :unit, optional: true

  has_many :payroll_items, dependent: :destroy

  has_many :salary_changes,
           -> { order(effective_on: :desc, created_at: :desc) },
           class_name: "EmployeeSalaryChange",
           dependent: :destroy

  has_many :vacations,
           -> { order(accrual_started_on: :desc) },
           class_name: "EmployeeVacation",
           dependent: :destroy

  enum status: { active: "active", inactive: "inactive", terminated: "terminated" }, _default: "active"

  validates :name, presence: true
  validates :salary_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :started_on, presence: true
  validates :status, presence: true
  validates :terminated_on, presence: true, if: :terminated?
  validate :terminated_on_not_before_started_on

  after_create :create_initial_salary_change

  def payroll_balance(year:, month:)
    items = payroll_items.where(year: year, month: month)

    salary   = items.salary.sum(:amount_cents)
    advances = items.advance.sum(:amount_cents)
    bonuses  = items.bonus.sum(:amount_cents)
    discounts = items.discount.sum(:amount_cents)

    {
      salary_cents: salary,
      advances_cents: advances,
      bonuses_cents: bonuses,
      discounts_cents: discounts,
      net_to_pay_cents: salary + bonuses - advances - discounts
    }
  end

  # Whole months of employment as of reference_date. Uses terminated_on as the
  # effective end date whenever it applies (i.e. it isn't after reference_date).
  def employment_duration_in_months(reference_date: Date.current)
    return 0 if started_on.blank?

    end_date = [terminated_on, reference_date].compact.min
    return 0 if end_date < started_on

    months = (end_date.year * 12 + end_date.month) - (started_on.year * 12 + started_on.month)
    months -= 1 if end_date.day < started_on.day
    months
  end

  def employment_duration_label(reference_date: Date.current)
    months = employment_duration_in_months(reference_date: reference_date)
    return "menos de 1 mês" if months.zero?

    years = months / 12
    remaining_months = months % 12

    parts = []
    parts << "#{years} #{years == 1 ? "ano" : "anos"}" if years.positive?
    parts << "#{remaining_months} #{remaining_months == 1 ? "mês" : "meses"}" if remaining_months.positive?

    parts.join(" e ")
  end

  # Salary in effect on the given date, based on salary_changes history.
  # Falls back to the current salary_cents when there's no matching record
  # (e.g. history hasn't been backfilled yet).
  def salary_on(date)
    change = salary_changes.where("effective_on <= ?", date).order(effective_on: :desc, created_at: :desc).first
    change&.salary_cents || salary_cents
  end

  def human_status
    I18n.t("enums.employee.status.#{status}", default: status.to_s)
  end

  private

  def terminated_on_not_before_started_on
    return if terminated_on.blank? || started_on.blank?

    errors.add(:terminated_on, "não pode ser anterior à data de contratação") if terminated_on < started_on
  end

  def create_initial_salary_change
    salary_changes.create!(
      previous_salary_cents: nil,
      salary_cents: salary_cents,
      effective_on: started_on,
      change_type: "initial"
    )
  end
end
