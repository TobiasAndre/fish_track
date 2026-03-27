class Batch < ApplicationRecord
  has_many :batch_stockings, dependent: :destroy
  has_many :ponds, through: :batch_stockings

  belongs_to :product, optional: true

  accepts_nested_attributes_for :batch_stockings, allow_destroy: true, reject_if: :all_blank

  enum status: {
    active: "active",
    closed: "closed"
  }, _suffix: true

  enum stage: {
    juvenile: "juvenile",
    growout: "growout"
  }, _suffix: true

  validates :name, :started_on, :status, :stage, presence: true
  validates :batch_stockings, presence: true

  validate :stockings_must_belong_to_same_unit

  before_validation :sync_quantities_from_stockings

  def unit
    ponds.first&.unit
  end

  def recalculate_current_quantity!
    return if destroyed? || marked_for_destruction?

    total_current_quantity = batch_stockings.sum(:current_quantity)
    update_columns(current_quantity: total_current_quantity)
  end

  private

  def sync_quantities_from_stockings
    valid_stockings = batch_stockings.reject(&:marked_for_destruction?)
    return if valid_stockings.blank?

    self.initial_quantity = valid_stockings.sum { |stocking| stocking.quantity.to_i }

    self.current_quantity = valid_stockings.sum do |stocking|
      stocking.current_quantity.present? ? stocking.current_quantity.to_i : stocking.quantity.to_i
    end
  end

  def stockings_must_belong_to_same_unit
    valid_stockings = batch_stockings.reject(&:marked_for_destruction?)
    return if valid_stockings.blank?

    unit_ids = valid_stockings.map { |s| s.pond&.unit_id }.compact.uniq
    return if unit_ids.size <= 1

    errors.add(:base, "Os tanques selecionados devem pertencer à mesma unidade")
  end
end
