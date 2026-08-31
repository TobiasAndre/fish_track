class PaymentTerm < ApplicationRecord
  include Loggable

  validates :name, presence: true, uniqueness: true
  validates :active, inclusion: { in: [true, false] }
  validates :days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  private

  def activity_description
    "Condição de pagamento #{name}"
  end
end
