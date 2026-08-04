FactoryBot.define do
  factory :employee do
    sequence(:name) { |n| "Funcionário #{n}" }
    role { "Operador" }
    salary_cents { 300_000 }
    started_on { Date.current }
  end
end
