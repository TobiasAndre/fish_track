FactoryBot.define do
  factory :stocking_event do
    association :batch_stocking, strategy: :create
    occurred_on { Date.current }
    event_type { "mortality" }
    quantity { 10 }

    trait :mortality do
      event_type { "mortality" }
      quantity { 10 }
    end

    trait :biometrics do
      event_type { "biometrics" }
      volume { 1000 }
      quantity { 950 }
      total_weight_kg { 4.75 }
    end

    trait :loading do
      event_type { "loading" }
      total_weight_kg { 100 }
      avg_weight_g { 500 }
    end

    trait :feeding do
      event_type { "feeding" }
      association :feeding_type, strategy: :create
      feed_kg { 50 }
      total_cents { 25_000 }
    end
  end
end
