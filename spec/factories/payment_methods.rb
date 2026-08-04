FactoryBot.define do
  factory :payment_method do
    sequence(:name) { |n| "Método #{n}" }
    active { true }
  end
end
