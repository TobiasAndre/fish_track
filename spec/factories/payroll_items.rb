FactoryBot.define do
  factory :payroll_item do
    employee
    year { Date.current.year }
    month { Date.current.month }
    amount_cents { 200_000 }
    item_type { "salary" }
    occurred_on { Date.current }
  end
end
