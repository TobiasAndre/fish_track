FactoryBot.define do
  factory :feeding_weight_range do
    sequence(:weight_from) { |n| n * 10 }
    sequence(:weight_to) { |n| (n * 10) + 9 }
  end
end
