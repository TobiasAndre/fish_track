FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "Cliente #{n}" }
  end
end
