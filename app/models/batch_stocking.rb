class BatchStocking < ApplicationRecord
  belongs_to :batch
  belongs_to :pond
  belongs_to :supplier, optional: true

  has_many :stocking_events, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :stocked_on, presence: true
  validates :avg_weight_g, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  before_validation :initialize_current_fields, on: :create

  def recalculate_current_balance!
    base_quantity = quantity.to_i
    base_biomass_kg =
      if quantity.present? && avg_weight_g.present?
        (quantity.to_d * avg_weight_g.to_d) / 1000
      else
        0.to_d
      end

    current_quantity_value = base_quantity
    current_biomass_value = base_biomass_kg

    ordered_events = stocking_events.order(:occurred_on, :created_at)

    ordered_events.each do |event|
      case event.event_type
      when "mortality"
        dead_quantity = event.quantity.to_i
        avg_weight = event_avg_weight_for(event)

        current_quantity_value -= dead_quantity
        current_biomass_value -= (dead_quantity.to_d * avg_weight.to_d) / 1000

      when "loading"
        loaded_quantity = event.quantity.to_i
        avg_weight = event_avg_weight_for(event)

        current_quantity_value -= loaded_quantity
        current_biomass_value -= (loaded_quantity.to_d * avg_weight.to_d) / 1000
      end
    end

    current_quantity_value = [current_quantity_value, 0].max
    current_biomass_value = [current_biomass_value, 0.to_d].max

    update_columns(
      current_quantity: current_quantity_value,
      current_biomass_kg: current_biomass_value.round(3)
    )

    return unless batch.present?
    return if batch.destroyed? || batch.marked_for_destruction?

    batch.recalculate_current_quantity!
  end

  private

  def initialize_current_fields
    self.current_quantity ||= quantity.to_i

    if avg_weight_g.present? && quantity.present?
      self.current_biomass_kg ||= (quantity.to_d * avg_weight_g.to_d) / 1000
    else
      self.current_biomass_kg ||= 0
    end
  end

  def event_avg_weight_for(event)
    return event.avg_weight_g.to_d if event.avg_weight_g.present?

    previous_biometry = stocking_events
      .where(event_type: "biometrics")
      .where("occurred_on <= ?", event.occurred_on)
      .where.not(id: event.id)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    previous_biometry&.avg_weight_g.to_d.presence || avg_weight_g.to_d || 0.to_d
  end
end
