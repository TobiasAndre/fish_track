FactoryBot.define do
  factory :feeding_brand do
    sequence(:name) { |n| "Marca de Ração #{n}" }
  end
end
