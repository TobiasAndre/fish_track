FactoryBot.define do
  factory :silo do
    unit
    sequence(:name) { |n| "Silo #{n}" }
  end
end
