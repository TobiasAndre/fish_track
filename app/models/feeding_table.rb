class FeedingTable < ApplicationRecord
  has_secure_token :share_token

  has_many :feeding_strategy_items, dependent: :destroy

  validates :name, presence: true
end