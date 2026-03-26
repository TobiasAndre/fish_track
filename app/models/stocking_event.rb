class StockingEvent < ApplicationRecord
  belongs_to :batch_stocking
  belongs_to :customer, optional: true
  belongs_to :integrated, optional: true
  belongs_to :payment_method, optional: true

  before_validation :normalize_numeric_fields
  before_validation :calculate_biometry_fields
  before_validation :calculate_loading_fields

  after_commit :update_batch_avg_weight, on: %i[create update]
  after_commit :recalculate_batch_stocking_balance, on: %i[create update destroy]

  EVENT_TYPES = %w[biometrics mortality feeding loading].freeze

  enum event_type: {
    biometrics: "biometrics",
    mortality: "mortality",
    feeding: "feeding",
    loading: "loading"
  }, _suffix: true

  private

  def calculate_loading_fields
    return unless loading?
    return if total_weight_kg.blank? || avg_weight_g.blank?
    return if avg_weight_g.to_d <= 0

    self.quantity = ((total_weight_kg.to_d * 1000) / avg_weight_g.to_d).ceil
  end

  def calculate_biometry_fields
    return unless biometry?

    self.weight_gain_kg = 0
    self.gpd = 0

    if quantity.present? && total_weight_kg.present? && quantity.to_d > 0
      self.avg_weight_g = (total_weight_kg.to_d / quantity.to_d) * 1000
    end

    if volume.present? && avg_weight_g.present?
      self.biomass = volume.to_d * (avg_weight_g.to_d / 1000)
    else
      self.biomass = nil
    end

    calculate_weight_gain_and_gpd
  end

  def calculate_weight_gain_and_gpd
    return if biomass.blank? || avg_weight_g.blank? || occurred_on.blank?

    previous_biometry = previous_biometry_event
    return unless previous_biometry.present?

    previous_biomass = previous_biometry.biomass.to_d
    previous_avg_weight = previous_biometry.avg_weight_g.to_d
    previous_date = previous_biometry.occurred_on

    self.weight_gain_kg = biomass.to_d - previous_biomass

    days_diff = (occurred_on - previous_date).to_i
    return if days_diff <= 0

    self.gpd = (avg_weight_g.to_d - previous_avg_weight) / days_diff
  end

  def previous_biometry_event
    scope = batch_stocking.stocking_events.where(event_type: "biometrics")
    scope = scope.where.not(id: id) if persisted?

    if occurred_on.present?
      scope
        .where(
          "occurred_on < ? OR (occurred_on = ? AND created_at < ?)",
          occurred_on,
          occurred_on,
          created_at || Time.current
        )
        .order(occurred_on: :desc, created_at: :desc)
        .first
    else
      scope
        .order(occurred_on: :desc, created_at: :desc)
        .first
    end
  end

  def update_batch_avg_weight
    return unless biometry?
    return if avg_weight_g.blank?

    batch = batch_stocking&.batch
    return unless batch

    last_biometry = batch_stocking.stocking_events
      .where(event_type: "biometrics")
      .order(occurred_on: :desc, created_at: :desc)
      .first

    return unless last_biometry&.avg_weight_g.present?

    batch.update(avg_weight_g: last_biometry.avg_weight_g)
  end

  def recalculate_batch_stocking_balance
    batch_stocking.recalculate_current_balance!
  end

  def biometry?
    event_type == "biometrics"
  end

  def loading?
    event_type == "loading"
  end

  def normalize_numeric_fields
    normalize_integer_field(:volume)
    normalize_integer_field(:quantity)

    normalize_decimal_field(:total_weight_kg)
    normalize_decimal_field(:avg_weight_g)
    normalize_decimal_field(:biomass)
    normalize_decimal_field(:weight_gain_kg)
    normalize_decimal_field(:gpd)
  end

  def normalize_integer_field(field)
    value = read_attribute_before_type_cast(field)
    return if value.blank?

    self[field] = value.to_s.gsub(/\D/, "").to_i
  end

  def normalize_decimal_field(field)
    value = read_attribute_before_type_cast(field)
    return if value.blank?

    normalized = value.to_s.gsub(".", "").tr(",", ".")
    self[field] = normalized.to_d
  end
end
