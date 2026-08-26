FactoryBot.define do
  factory :silo_stock_entry do
    association :silo, strategy: :create
    association :feeding_type, strategy: :create
    occurred_on { Date.current }
    quantity_kg { 500 }
    total_cents { 250_000 }
  end
end
