class Order < ApplicationRecord
  belongs_to :customer
  belongs_to :payment_method, optional: true
  belongs_to :payment_term, optional: true
  
  STATUSES = %w[draft confirmed delivered canceled].freeze

  validates :customer, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :occurred_on, presence: true
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
end
