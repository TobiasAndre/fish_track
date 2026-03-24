class Integrated < ApplicationRecord
  belongs_to :customer
  has_many :simulations

  validates :name, presence: true
end
