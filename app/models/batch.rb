class Batch < ApplicationRecord
   belongs_to :pond
  has_one :unit, through: :pond
  has_one :company, through: :unit

  has_many :batch_events, dependent: :destroy
  has_many :financial_entries, dependent: :nullify

  enum stage: {
    nursery: "nursery",   # berçário
    juvenile: "juvenile", # juvenil
    growout: "growout"    # engorda
  }

  enum status: {
    active: "active",
    closed: "closed"
  }

  validates :name, presence: true
  validates :status, presence: true
  validates :stage, presence: true
  validates :started_on, presence: true

  validates :initial_quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :current_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :avg_weight_g, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
