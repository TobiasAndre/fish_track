class BatchStocking < ApplicationRecord
  belongs_to :batch
  belongs_to :pond
  belongs_to :supplier, optional: true

  has_many :stocking_events, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :stocked_on, presence: true
  validates :avg_weight_g, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  before_validation :initialize_current_fields, on: :create
  after_commit :create_initial_biometry_event, on: :create

  def recalculate_current_balance!
    base_quantity = quantity.to_i
    current_quantity_value = base_quantity

    current_avg_weight = latest_avg_weight_for_balance
    current_biomass_value =
      if current_quantity_value.positive? && current_avg_weight.positive?
        (current_quantity_value.to_d * current_avg_weight.to_d) / 1000
      else
        0.to_d
      end

    ordered_events = stocking_events.order(:occurred_on, :created_at)

    ordered_events.each do |event|
      case event.event_type
      when "biometrics"
        if event.avg_weight_g.present?
          current_avg_weight = event.avg_weight_g.to_d
          current_biomass_value =
            if current_quantity_value.positive? && current_avg_weight.positive?
              (current_quantity_value.to_d * current_avg_weight.to_d) / 1000
            else
              0.to_d
            end
        end

      when "mortality"
        dead_quantity = event.quantity.to_i
        avg_weight = event_avg_weight_for(event, current_avg_weight)

        current_quantity_value -= dead_quantity
        current_quantity_value = [current_quantity_value, 0].max

        current_biomass_value -= (dead_quantity.to_d * avg_weight.to_d) / 1000
        current_biomass_value = [current_biomass_value, 0.to_d].max

      when "loading"
        loaded_quantity = event.quantity.to_i
        avg_weight = event_avg_weight_for(event, current_avg_weight)

        current_quantity_value -= loaded_quantity
        current_quantity_value = [current_quantity_value, 0].max

        current_biomass_value -= (loaded_quantity.to_d * avg_weight.to_d) / 1000
        current_biomass_value = [current_biomass_value, 0.to_d].max
      end
    end

    update_columns(
      current_quantity: current_quantity_value,
      current_biomass_kg: current_biomass_value.round(3)
    )

    return unless batch.present?
    return if batch.destroyed? || batch.marked_for_destruction?

    batch.recalculate_current_quantity!
    batch.recalculate_current_biomass!
  end

  private

  def initialize_current_fields
    return if quantity.blank?

    self.current_quantity = quantity.to_i if current_quantity.blank?

    if avg_weight_g.present?
      self.current_biomass_kg = (quantity.to_d * avg_weight_g.to_d) / 1000 if current_biomass_kg.blank?
    else
      self.current_biomass_kg = 0 if current_biomass_kg.blank?
    end
  end

  def create_initial_biometry_event
    return if stocked_on.blank?
    return if quantity.blank? || quantity.to_i <= 0
    return if avg_weight_g.blank? || avg_weight_g.to_d <= 0

    existing_initial_biometry = stocking_events.find_by(
      event_type: "biometrics",
      occurred_on: stocked_on,
      quantity: quantity.to_i
    )

    return if existing_initial_biometry.present?

    total_weight_kg = (quantity.to_d * avg_weight_g.to_d) / 1000
    initial_volume = current_quantity.presence || quantity

    stocking_events.create!(
      event_type: "biometrics",
      occurred_on: stocked_on,
      quantity: quantity.to_i,
      volume: initial_volume.to_i,
      avg_weight_g: avg_weight_g.to_d,
      total_weight_kg: total_weight_kg
    )
  end

  def latest_avg_weight_for_balance
    latest_biometry = stocking_events
      .where(event_type: "biometrics")
      .order(occurred_on: :desc, created_at: :desc)
      .first

    latest_biometry&.avg_weight_g.to_d.presence || avg_weight_g.to_d || 0.to_d
  end

  def event_avg_weight_for(event, fallback_avg_weight = 0.to_d)
    return event.avg_weight_g.to_d if event.avg_weight_g.present?

    previous_biometry = stocking_events
      .where(event_type: "biometrics")
      .where("occurred_on <= ?", event.occurred_on)
      .where.not(id: event.id)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    previous_biometry&.avg_weight_g.to_d.presence || fallback_avg_weight.to_d || avg_weight_g.to_d || 0.to_d
  end
end
