FactoryBot.define do
  factory :feeding_strategy_item do
    feeding_table
    feeding_weight_range
    feeding_temperature_range
    feeding_percentage { 3.5 }
  end
end
