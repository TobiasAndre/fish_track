FactoryBot.define do
  factory :employee_salary_change do
    employee
    salary_cents { 300_000 }
    effective_on { Date.current }
    change_type { "adjustment" }
  end
end
