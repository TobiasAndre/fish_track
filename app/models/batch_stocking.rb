class BatchStocking < ApplicationRecord
  belongs_to :batch
  belongs_to :pond
  belongs_to :supplier, optional: true

  has_many :stocking_events, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :stocked_on, presence: true
  validates :avg_weight_g, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
end
