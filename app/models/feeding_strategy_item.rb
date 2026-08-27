class FeedingStrategyItem < ApplicationRecord
  include Loggable

  belongs_to :feeding_table
  belongs_to :feeding_weight_range
  belongs_to :feeding_temperature_range

  validates :feeding_percentage, presence: true

  private

  def activity_description
    weight_label = "#{feeding_weight_range&.weight_from}-#{feeding_weight_range&.weight_to}g"
    temp_label = "#{feeding_temperature_range&.temperature_from}-#{feeding_temperature_range&.temperature_to}°C"

    "Estratégia - #{feeding_table&.name} - #{weight_label} / #{temp_label}"
  end
end