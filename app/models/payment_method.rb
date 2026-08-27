class PaymentMethod < ApplicationRecord
  include Loggable

  validates :name, presence: true, uniqueness: true
  validates :active, inclusion: { in: [true, false] }

  private

  def activity_description
    "Forma de pagamento #{name}"
  end
end
