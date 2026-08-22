class StockingEvent < ApplicationRecord
  belongs_to :batch_stocking
  belongs_to :customer, optional: true
  belongs_to :integrated, optional: true
  belongs_to :payment_method, optional: true
  belongs_to :supplier, optional: true

  has_secure_token :share_token

  before_validation :normalize_numeric_fields
  before_validation :calculate_biometry_fields
  before_validation :calculate_loading_fields
  validates :occurred_on, presence: true
  validates :event_type, presence: true
  validates :batch_stocking_id, presence: true

  after_commit :update_batch_avg_weight, on: %i[create update]
  after_commit :recalculate_batch_stocking_balance, on: %i[create update destroy]

  before_destroy :capture_activity_snapshot
  after_commit :log_activity, on: %i[create update destroy]

  with_options if: :biometrics? do
    validates :volume, presence: true, numericality: { greater_than: 0 }
    validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :total_weight_kg, presence: true, numericality: { greater_than: 0 }
    validates :avg_weight_g, presence: true, numericality: { greater_than: 0 }
    validates :biomass, presence: true, numericality: { greater_than: 0 }
    validates :weight_gain_kg, presence: true
    validates :gpd, presence: true
  end

  EVENT_TYPES = %w[biometrics mortality feeding loading].freeze

  enum event_type: {
    biometrics: "biometrics",
    mortality: "mortality",
    feeding: "feeding",
    loading: "loading"
  }, _suffix: true

  scope :recent_first, -> { order(occurred_on: :desc, created_at: :desc) }

  def human_event_type
    I18n.t("stocking_events.event_types.#{event_type}", default: event_type.to_s)
  end

  private

  def capture_activity_snapshot
    @activity_snapshot = activity_description
  end

  def log_activity
    return unless Current.user

    ActivityLog.record!(
      user: Current.user,
      action: activity_action,
      resource_type: "StockingEvent",
      resource_id: id,
      event_type: event_type,
      description: @activity_snapshot || activity_description
    )
  end

  def activity_action
    return "destroy" if destroyed?

    previously_new_record? ? "create" : "update"
  end

  def activity_description
    label = I18n.t("enums.stocking_event.event_type.#{event_type}", default: event_type.to_s)
    batch_label = batch_stocking&.display_name || "Lote ##{batch_stocking_id}"
    date_label = occurred_on.present? ? I18n.l(occurred_on) : "sem data"

    "#{label} - #{batch_label} - #{date_label}"
  end

  def calculate_loading_fields
    return unless loading?

    calculate_loading_quantity
    calculate_total_cents
  end

  def calculate_loading_quantity
    return if total_weight_kg.blank? || avg_weight_g.blank?
    return if avg_weight_g.to_d <= 0

    self.quantity = ((total_weight_kg.to_d * 1000) / avg_weight_g.to_d).ceil
  end

  def calculate_total_cents
    fish_total_cents = total_weight_kg.to_d * price_per_kg_cents.to_i

    if quantity.present?
      fish_total_cents += thousand_value_cents.to_i * (quantity.to_d / 1000)
    end

    subtotal_cents =
      fish_total_cents +
      loading_cost_cents.to_i +
      freight_cost_cents.to_i

    tax_cents = subtotal_cents * (tax_percentage.to_d / 100)

    self.total_cents = (subtotal_cents + tax_cents).round
  end

  def calculate_biometry_fields
    return unless biometrics?

    self.weight_gain_kg = 0
    self.gpd = 0
    self.feed_conversion = 0

    if quantity.present? && total_weight_kg.present? && quantity.to_d > 0
      self.avg_weight_g = (total_weight_kg.to_d / quantity.to_d) * 1000
    end

    if volume.present? && avg_weight_g.present?
      self.biomass = volume.to_d * (avg_weight_g.to_d / 1000)
    else
      self.biomass = nil
    end

    calculate_weight_gain_and_gpd
    calculate_feed_conversion
  end

  def calculate_feed_conversion
    return unless biometrics?

    self.feed_conversion = 0

    return if feed_kg.blank?
    return if weight_gain_kg.blank? || weight_gain_kg.to_d <= 0

    self.feed_conversion = feed_kg.to_d / weight_gain_kg.to_d
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
    return unless biometrics?
    return if avg_weight_g.blank?

    batch = batch_stocking&.batch
    return unless batch
    return if batch.destroyed? || batch.marked_for_destruction?

    last_biometry = batch_stocking.stocking_events
      .where(event_type: "biometrics")
      .order(occurred_on: :desc, created_at: :desc)
      .first

    return unless last_biometry&.avg_weight_g.present?

    batch.update(avg_weight_g: last_biometry.avg_weight_g)
  end

  def recalculate_batch_stocking_balance
    return unless batch_stocking.present?
    return if batch_stocking.destroyed? || batch_stocking.marked_for_destruction?
    return unless batch_stocking.persisted?

    batch_stocking.recalculate_current_balance!
  end

  def biometrics?
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
    normalize_decimal_field(:feed_kg)
    normalize_decimal_field(:feed_conversion)
    normalize_decimal_field(:tax_percentage)
  end

  def normalize_integer_field(field)
    value = read_attribute_before_type_cast(field)
    return if value.blank?

    self[field] = value.to_s.gsub(/\D/, "").to_i
  end

  def normalize_decimal_field(field)
    value = read_attribute_before_type_cast(field)
    return if value.blank?

    string_value = value.to_s.strip

    normalized =
      if string_value.include?(",")
        string_value.gsub(".", "").tr(",", ".")
      else
        string_value
      end

    self[field] = normalized.to_d
  end
end
