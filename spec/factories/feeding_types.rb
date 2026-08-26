FactoryBot.define do
  factory :feeding_type do
    association :feeding_brand, strategy: :create
    sequence(:name) { |n| "Tipo de Ração #{n}" }
  end
end
