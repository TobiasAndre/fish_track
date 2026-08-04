FactoryBot.define do
  factory :unit do
    sequence(:name) { |n| "Unidade #{n}" }
  end
end
