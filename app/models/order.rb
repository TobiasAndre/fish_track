class Order < ApplicationRecord
  include Loggable

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

  after_save :recalculate_total_cents!

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

  def activity_description
    "Pedido ##{id} - #{customer&.name} (#{status})"
  end

  # Runs after save (rather than before_validation) because the nested
  # order_items only get their own total_cents computed and persisted
  # during the autosave step that follows this record's own validation.
  def recalculate_total_cents!
    new_total = order_items.reload.sum(:total_cents)
    update_column(:total_cents, new_total) if new_total != total_cents
  end
end
