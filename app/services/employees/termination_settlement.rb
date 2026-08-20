module Employees
  # Calculates the "acerto rescisório" (termination settlement) for a terminated
  # employee: proportional salary balance for the days worked in the termination
  # month, proportional 13º salário, and proportional férias + 1/3 constitucional.
  #
  # Avos (twelfths) follow the CLT rule: a full contractual month counts as one
  # avo, and a remaining fraction of 15 days or more also counts as one avo.
  # This intentionally does not include vencidas (already-due, untaken) vacation,
  # aviso prévio, FGTS or tax withholding -- only the proportional pieces the
  # employee asked for.
  class TerminationSettlement
    Result = Struct.new(
      :reference_date,
      :salary_cents,
      :days_worked_in_month,
      :days_in_month,
      :balance_salary_cents,
      :thirteenth_months,
      :thirteenth_cents,
      :vacation_period_start,
      :vacation_months,
      :vacation_cents,
      :total_cents,
      keyword_init: true
    )

    def initialize(employee, reference_date: nil)
      @employee = employee
      @reference_date = reference_date || employee.terminated_on || Date.current
    end

    def call
      Result.new(
        reference_date: reference_date,
        salary_cents: salary_cents,
        days_worked_in_month: days_worked_in_month,
        days_in_month: days_in_month,
        balance_salary_cents: balance_salary_cents,
        thirteenth_months: thirteenth_months,
        thirteenth_cents: thirteenth_cents,
        vacation_period_start: vacation_period_start,
        vacation_months: vacation_months,
        vacation_cents: vacation_cents,
        total_cents: balance_salary_cents + thirteenth_cents + vacation_cents
      )
    end

    private

    attr_reader :employee, :reference_date

    def salary_cents
      employee.salary_on(reference_date).to_i
    end

    def days_in_month
      Date.new(reference_date.year, reference_date.month, -1).day
    end

    def days_worked_in_month
      reference_date.day
    end

    def balance_salary_cents
      return 0 if salary_cents.zero?

      (salary_cents * days_worked_in_month / days_in_month.to_f).round
    end

    def thirteenth_months
      year_start = [Date.new(reference_date.year, 1, 1), employee.started_on].compact.max
      avos_between(year_start, reference_date)
    end

    def thirteenth_cents
      ((salary_cents / 12.0) * thirteenth_months).round
    end

    def vacation_period_start
      accruing = employee.vacations.detect { |vacation| vacation.status == "accruing" }
      return accruing.accrual_started_on if accruing&.accrual_started_on.present?

      return nil if employee.started_on.blank?

      elapsed_months = (reference_date.year * 12 + reference_date.month) -
        (employee.started_on.year * 12 + employee.started_on.month)
      completed_cycles = [elapsed_months / 12, 0].max

      employee.started_on.advance(months: completed_cycles * 12)
    end

    def vacation_months
      avos_between(vacation_period_start, reference_date)
    end

    def vacation_cents
      base = (salary_cents / 12.0) * vacation_months
      (base * 4 / 3.0).round
    end

    # Whole contractual months between `from` and `to` (anchored on from's
    # day-of-month, like Employee#employment_duration_in_months), plus one more
    # avo if the remaining fraction is 15 days or more. Capped at 12.
    def avos_between(from, to)
      return 0 if from.blank? || to.blank? || to < from

      whole_months = (to.year * 12 + to.month) - (from.year * 12 + from.month)
      whole_months -= 1 if to.day < from.day
      whole_months = [whole_months, 0].max

      last_anniversary = from.advance(months: whole_months)
      remaining_days = (to - last_anniversary).to_i
      whole_months += 1 if remaining_days >= 15

      [whole_months, 12].min
    end
  end
end
