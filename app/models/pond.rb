class Pond < ApplicationRecord
  include Loggable

  belongs_to :unit

  has_many :batch_stockings, dependent: :destroy
  has_many :batches, through: :batch_stockings

  validates :order_number, numericality: { only_integer: true }, allow_nil: true
  validates :feed_sample_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :feed_sample_seconds, numericality: { greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:order_number, :id) }

  def full_name
    [unit&.name, name].compact.join(" - ")
  end

  # Segundos de trato por kg de ração, a partir da amostra de calibração
  # (ex.: 964 s para 650 kg -> 1,4831 s/kg). Nil se não calibrado.
  def feed_seconds_per_kg
    return if feed_sample_kg.to_d.zero? || feed_sample_seconds.blank?

    feed_sample_seconds.to_d / feed_sample_kg.to_d
  end

  private

  def activity_description
    "Tanque #{full_name}"
  end
end
