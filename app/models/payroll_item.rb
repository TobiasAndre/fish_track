class PayrollItem < ApplicationRecord
  belongs_to :company
  belongs_to :employee

  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :amount_cents, numericality: { greater_than: 0 }
end
