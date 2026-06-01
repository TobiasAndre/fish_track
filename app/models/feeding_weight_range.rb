class FeedingWeightRange < ApplicationRecord
  has_many :feeding_strategy_items, dependent: :restrict_with_error

  validates :weight_from, :weight_to, presence: true
end