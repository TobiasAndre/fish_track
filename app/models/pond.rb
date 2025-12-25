class Pond < ApplicationRecord
  belongs_to :unit
  has_one :company, through: :unit

  has_many :batches, dependent: :destroy

  validates :name, presence: true

end
