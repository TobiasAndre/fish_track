FactoryBot.define do
  factory :employee_vacation do
    employee
    accrual_started_on { 1.year.ago.to_date }
    accrual_ended_on { Date.current }
    status { "accruing" }
    entitled_days { 30 }
    taken_days { 0 }
  end
end
