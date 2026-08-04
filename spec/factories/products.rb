FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Produto #{n}" }
    sequence(:sku) { |n| "SKU-#{n}" }
    unit { "kg" }
    active { true }
  end
end
