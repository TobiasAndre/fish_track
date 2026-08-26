class Unit < ApplicationRecord
  has_many :ponds, dependent: :destroy
  has_many :silos, dependent: :destroy

  validates :name, presence: true
end
