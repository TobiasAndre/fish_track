class EmployeeVacation < ApplicationRecord
  belongs_to :employee

  STATUSES = %w[accruing available scheduled taken partially_taken cancelled].freeze

  validates :accrual_started_on, presence: true
  validates :accrual_ended_on, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :entitled_days, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :taken_days, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :accrual_period_is_chronological
  validate :scheduled_period_is_valid
  validate :taken_period_is_valid
  validate :taken_days_within_entitled_days

  scope :recent_first, -> { order(accrual_started_on: :desc) }

  def human_status
    I18n.t("enums.employee_vacation.status.#{status}", default: status.to_s)
  end

  private

  def accrual_period_is_chronological
    return if accrual_started_on.blank? || accrual_ended_on.blank?

    if accrual_ended_on < accrual_started_on
      errors.add(:accrual_ended_on, "deve ser posterior ao início do período aquisitivo")
    end
  end

  def scheduled_period_is_valid
    return if scheduled_start_on.blank? && scheduled_end_on.blank?

    if scheduled_start_on.blank? || scheduled_end_on.blank?
      errors.add(:base, "Informe as duas datas do período programado de férias")
    elsif scheduled_end_on < scheduled_start_on
      errors.add(:scheduled_end_on, "deve ser posterior ao início do período programado")
    end
  end

  def taken_period_is_valid
    return if taken_start_on.blank? && taken_end_on.blank?

    if taken_start_on.blank? || taken_end_on.blank?
      errors.add(:base, "Informe as duas datas do período de férias realizado")
    elsif taken_end_on < taken_start_on
      errors.add(:taken_end_on, "deve ser posterior ao início do período realizado")
    end
  end

  def taken_days_within_entitled_days
    return if taken_days.blank? || entitled_days.blank?

    errors.add(:taken_days, "não pode ser maior que os dias disponíveis") if taken_days > entitled_days
  end
end
