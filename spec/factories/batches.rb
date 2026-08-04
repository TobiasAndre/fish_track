FactoryBot.define do
  factory :batch do
    sequence(:name) { |n| "Lote #{n}" }
    species { "Tilápia" }
    status { "active" }
    stage { "juvenile" }
    started_on { Date.current }

    transient do
      pond { association(:pond) }
      stocking_quantity { 1000 }
      stocking_avg_weight_g { 5.0 }
      stocked_on { Date.current }
    end

    after(:build) do |batch, evaluator|
      next if batch.batch_stockings.any?

      batch.batch_stockings.build(
        pond: evaluator.pond,
        quantity: evaluator.stocking_quantity,
        avg_weight_g: evaluator.stocking_avg_weight_g,
        stocked_on: evaluator.stocked_on
      )
    end
  end
end
