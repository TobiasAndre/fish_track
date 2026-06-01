class FeedingTable < ApplicationRecord
  has_many :feeding_strategy_items, dependent: :destroy

  validates :name, presence: true
end