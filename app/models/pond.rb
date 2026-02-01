class Pond < ApplicationRecord
  belongs_to :unit

  has_many :batches, dependent: :destroy

  validates :name, presence: true

end
