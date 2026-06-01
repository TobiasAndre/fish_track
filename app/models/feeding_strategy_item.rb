class FeedingStrategyItem < ApplicationRecord
  belongs_to :feeding_table
  belongs_to :feeding_weight_range
  belongs_to :feeding_temperature_range

  validates :feeding_percentage, presence: true
end