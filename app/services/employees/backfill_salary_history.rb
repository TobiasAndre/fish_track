module Employees
  # Idempotent: only creates an initial salary_changes record for employees
  # that don't have ANY salary history yet. Safe to run repeatedly.
  class BackfillSalaryHistory
    def self.call
      new.call
    end

    def call
      created = 0

      Employee.find_each do |employee|
        next if employee.salary_changes.exists?

        employee.salary_changes.create!(
          previous_salary_cents: nil,
          salary_cents: employee.salary_cents,
          effective_on: employee.started_on,
          change_type: "initial"
        )
        created += 1
      end

      created
    end
  end
end
