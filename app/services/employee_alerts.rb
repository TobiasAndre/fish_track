# Computes administrative alerts for an employee as of a reference date.
# Purely calculated (no persistence) so it always reflects current data.
class EmployeeAlerts
  Alert = Struct.new(:type, :severity, :title, :message, :due_on, :employee, keyword_init: true)

  ANNIVERSARY_WINDOW_DAYS = 30
  SCHEDULED_VACATION_WINDOW_DAYS = 30
  VACATION_PAYMENT_WINDOW_DAYS = 15

  def initialize(employee, reference_date: Date.current)
    @employee = employee
    @reference_date = reference_date
  end

  def call
    [
      anniversary_alert,
      *available_vacation_alerts,
      *scheduled_vacation_alerts,
      *pending_vacation_payment_alerts
    ].compact.sort_by { |alert| alert.due_on }
  end

  private

  attr_reader :employee, :reference_date

  def anniversary_alert
    return nil if employee.started_on.blank?
    return nil if employee.respond_to?(:terminated?) && employee.terminated?

    next_anniversary = next_anniversary_date
    return nil if next_anniversary.blank?

    days_until = (next_anniversary - reference_date).to_i
    return nil unless days_until.between?(0, ANNIVERSARY_WINDOW_DAYS)

    years = next_anniversary.year - employee.started_on.year

    Alert.new(
      type: :contract_anniversary,
      severity: :info,
      title: "Aniversário de contrato próximo",
      message: "#{employee.name} completa #{years} #{years == 1 ? "ano" : "anos"} de empresa em " \
                "#{I18n.l(next_anniversary)}.",
      due_on: next_anniversary,
      employee: employee
    )
  end

  def next_anniversary_date
    started_on = employee.started_on
    return nil if started_on.blank?

    # An anniversary only exists from 1 full year of employment onward --
    # never returns started_on itself (that would be "0 years", not an anniversary).
    years_since_start = [reference_date.year - started_on.year, 1].max

    candidate = started_on.change(year: started_on.year + years_since_start)
    candidate = candidate.change(year: candidate.year + 1) if candidate < reference_date
    candidate
  rescue ArgumentError
    # started_on é 29/fev e o ano candidato não é bissexto
    nil
  end

  def available_vacation_alerts
    employee.vacations.where(status: "available").map do |vacation|
      Alert.new(
        type: :vacation_available,
        severity: :info,
        title: "Férias disponíveis",
        message: "#{employee.name} possui #{vacation.entitled_days} dia(s) de férias disponíveis para agendamento.",
        due_on: vacation.accrual_ended_on,
        employee: employee
      )
    end
  end

  def scheduled_vacation_alerts
    employee.vacations.where(status: "scheduled").filter_map do |vacation|
      next if vacation.scheduled_start_on.blank?

      days_until = (vacation.scheduled_start_on - reference_date).to_i
      next unless days_until.between?(0, SCHEDULED_VACATION_WINDOW_DAYS)

      Alert.new(
        type: :vacation_scheduled,
        severity: days_until <= 7 ? :warning : :info,
        title: "Férias programadas",
        message: "Férias de #{employee.name} começam em #{I18n.l(vacation.scheduled_start_on)}.",
        due_on: vacation.scheduled_start_on,
        employee: employee
      )
    end
  end

  def pending_vacation_payment_alerts
    employee.vacations.where(paid_on: nil).where.not(payment_due_on: nil).filter_map do |vacation|
      days_until = (vacation.payment_due_on - reference_date).to_i
      next if days_until > VACATION_PAYMENT_WINDOW_DAYS

      overdue = days_until.negative?

      Alert.new(
        type: :vacation_payment_pending,
        severity: overdue ? :danger : :warning,
        title: overdue ? "Pagamento de férias vencido" : "Pagamento de férias próximo",
        message:
          if overdue
            "O pagamento de férias de #{employee.name} venceu em #{I18n.l(vacation.payment_due_on)}."
          else
            "O pagamento de férias de #{employee.name} vence em #{I18n.l(vacation.payment_due_on)}."
          end,
        due_on: vacation.payment_due_on,
        employee: employee
      )
    end
  end
end
