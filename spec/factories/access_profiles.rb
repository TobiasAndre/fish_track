FactoryBot.define do
  factory :access_profile do
    sequence(:name) { |n| "Perfil #{n}" }
    description { nil }
  end
end
