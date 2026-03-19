class Pond < ApplicationRecord
  belongs_to :unit

  has_many :batch_stockings, dependent: :destroy
  has_many :batches, through: :batch_stockings
end
