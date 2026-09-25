class WaterQualityReading < ApplicationRecord
  include Loggable

  belongs_to :pond

  # chave => rótulo, unidade, casas decimais, cor do gráfico
  PARAMETERS = {
    ph:         { label: "pH",           unit: nil,          decimals: 2, color: "#4f46e5" },
    nitrite:    { label: "Nitrito",      unit: "mg/L",       decimals: 3, color: "#dc2626" },
    ammonia:    { label: "Amônia",       unit: "mg/L",       decimals: 3, color: "#d97706" },
    alkalinity: { label: "Alcalinidade", unit: "mg/L CaCO₃", decimals: 2, color: "#0891b2" },
    salinity:   { label: "Salinidade",   unit: "ppt",        decimals: 2, color: "#059669" }
  }.freeze

  validates :measured_at, presence: true
  validates :ph, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validates :nitrite, :ammonia, :alkalinity, :salinity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :at_least_one_parameter
  validate :measured_at_not_in_the_future

  scope :chronological, -> { order(:measured_at, :id) }
  scope :recent_first, -> { order(measured_at: :desc, id: :desc) }
  scope :measured_between, ->(from, to) { where(measured_at: from.beginning_of_day..to.end_of_day) }

  # Última análise de cada tanque: { pond_id => reading }.
  def self.latest_by_pond_id
    select("DISTINCT ON (water_quality_readings.pond_id) water_quality_readings.*")
      .order("water_quality_readings.pond_id", measured_at: :desc, id: :desc)
      .index_by(&:pond_id)
  end

  def value_for(parameter)
    self[parameter]
  end

  private

  def at_least_one_parameter
    return if PARAMETERS.keys.any? { |parameter| self[parameter].present? }

    errors.add(:base, "Informe pelo menos um parâmetro (pH, nitrito, amônia, alcalinidade ou salinidade).")
  end

  def measured_at_not_in_the_future
    return if measured_at.blank? || measured_at <= Time.current.end_of_day

    errors.add(:measured_at, "não pode ser uma data futura")
  end

  def activity_description
    "Qualidade da água - #{pond&.full_name} - #{measured_at ? I18n.l(measured_at.to_date) : '—'}"
  end
end
