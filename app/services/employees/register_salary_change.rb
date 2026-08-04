module Employees
  # Records a new salary history entry for an employee and keeps
  # employees.salary_cents in sync with whatever is actually in effect today.
  #
  # A change effective in the future is recorded but does not touch the
  # employee's current salary. A change effective today or in the past
  # (including a correction inserted out of chronological order) causes
  # employees.salary_cents to be recomputed from history, so it always
  # reflects the salary that is genuinely vigente as of today.
  class RegisterSalaryChange
    def initialize(employee:, salary_cents:, effective_on:, change_type:, reason: nil, created_by: nil)
      @employee = employee
      @salary_cents = salary_cents
      @effective_on = effective_on.is_a?(String) ? effective_on.presence&.to_date : effective_on
      @change_type = change_type
      @reason = reason
      @created_by = created_by
    end

    def call
      @employee.with_lock do
        salary_change = @employee.salary_changes.create!(
          previous_salary_cents: previous_salary_cents,
          salary_cents: @salary_cents,
          effective_on: @effective_on,
          change_type: @change_type,
          reason: @reason,
          created_by: @created_by
        )

        current_salary_cents = @employee.salary_on(Date.current)
        @employee.update!(salary_cents: current_salary_cents) if @employee.salary_cents != current_salary_cents

        salary_change
      end
    end

    private

    def previous_salary_cents
      return nil if @effective_on.blank?
      return nil unless @employee.salary_changes.exists?

      @employee.salary_on(@effective_on - 1)
    end
  end
end
