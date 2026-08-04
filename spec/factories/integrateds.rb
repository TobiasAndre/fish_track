FactoryBot.define do
  factory :integrated do
    customer
    sequence(:name) { |n| "Integrado #{n}" }
  end
end
