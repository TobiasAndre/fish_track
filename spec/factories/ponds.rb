FactoryBot.define do
  factory :pond do
    unit
    sequence(:name) { |n| "Tanque #{n}" }
    capacity { 1000 }
    capacity_unit { "m3" }
  end
end
