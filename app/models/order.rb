class Order < ApplicationRecord
  belongs_to :customer
  belongs_to :payment_method, optional: true
  belongs_to :payment_term, optional: true

  has_many :order_items, dependent: :destroy
  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  STATUSES = %w[draft confirmed delivered canceled].freeze

  validates :customer, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :occurred_on, presence: true
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_total_cents

  def canceled?
    status == "canceled"
  end

  def delivered?
    status == "delivered"
  end

  def cancelable?
    !delivered? && !canceled?
  end

  private

  def calculate_total_cents
    self.total_cents = order_items.reject(&:marked_for_destruction?).sum do |item|
      item.total_cents.to_i
    end
  end
end
