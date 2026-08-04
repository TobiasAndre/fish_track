FactoryBot.define do
  factory :simulation do
    customer
    simulated_on { Date.current }
    quantity { 1000 }
    avg_weight_kg { 0.5 }
    price_per_kg_cents { 1_500 }
    loading_count { 1 }
  end
end
