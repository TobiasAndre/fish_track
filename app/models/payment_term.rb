class PaymentTerm < ApplicationRecord
  include Loggable

  validates :name, presence: true, uniqueness: true
  validates :active, inclusion: { in: [true, false] }

  private

  def activity_description
    "Condição de pagamento #{name}"
  end
end
