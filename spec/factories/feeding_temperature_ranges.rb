FactoryBot.define do
  factory :feeding_temperature_range do
    sequence(:temperature_from) { |n| 20 + n }
    sequence(:temperature_to) { |n| 25 + n }
  end
end
