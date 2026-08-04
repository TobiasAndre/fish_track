FactoryBot.define do
  factory :supplier do
    sequence(:name) { |n| "Fornecedor #{n}" }
  end
end
