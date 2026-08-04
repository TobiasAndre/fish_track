FactoryBot.define do
  factory :payment_term do
    sequence(:name) { |n| "Prazo #{n}" }
    active { true }
  end
end
