class FeedingTemperatureRange < ApplicationRecord
  has_many :feeding_strategy_items, dependent: :restrict_with_error

  validates :temperature_from, :temperature_to, presence: true
end