FactoryBot.define do
  factory :order do
    customer
    payment_method
    payment_term
    status { "draft" }
    occurred_on { Date.current }
  end
end
