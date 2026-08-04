FactoryBot.define do
  factory :profile do
    association :user, strategy: :create
    display_name { "Perfil Teste" }
  end
end
