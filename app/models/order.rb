class Order < ApplicationRecord
  belongs_to :customer

  STATUSES = %w[draft confirmed delivered canceled].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :occurred_on, presence: true
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
end
