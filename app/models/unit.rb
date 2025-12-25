class Unit < ApplicationRecord
  belongs_to :company
  has_many :ponds, dependent: :destroy

  validates :name, presence: true
end
