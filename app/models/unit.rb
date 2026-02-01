class Unit < ApplicationRecord
  has_many :ponds, dependent: :destroy

  validates :name, presence: true
end
