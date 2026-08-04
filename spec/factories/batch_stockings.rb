FactoryBot.define do
  factory :batch_stocking do
    batch
    pond
    quantity { 1000 }
    avg_weight_g { 5.0 }
    stocked_on { Date.current }
  end
end
