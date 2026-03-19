class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_total_cents

  private

  def calculate_total_cents
    self.total_cents = (quantity.to_d * unit_price_cents.to_i).to_i
  end
end
