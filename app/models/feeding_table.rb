class FeedingTable < ApplicationRecord
  include Loggable

  has_secure_token :share_token

  has_many :feeding_strategy_items, dependent: :destroy

  validates :name, presence: true

  private

  def activity_description
    "Tabela de arraçoamento #{name}"
  end
end