FactoryBot.define do
  factory :financial_entry do
    entry_type { "expense" }
    stage { "general" }
    occurred_on { Date.current }
    amount_cents { 10_000 }
    description { "Despesa geral" }
  end
end
