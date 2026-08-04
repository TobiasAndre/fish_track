FactoryBot.define do
  factory :feeding_table do
    sequence(:name) { |n| "Tabela #{n}" }
    description { "Tabela de alimentação padrão" }
  end
end
