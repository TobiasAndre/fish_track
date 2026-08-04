FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Empresa #{n}" }
    sequence(:tenant_name) { |n| "empresa_#{n}" }
  end
end
