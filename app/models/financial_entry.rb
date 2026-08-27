class FinancialEntry < ApplicationRecord
  include Loggable

  belongs_to :batch, optional: true
  belongs_to :unit, optional: true # útil quando é "Geral Sede" sem lote
  belongs_to :silo_stock_entry, optional: true

  enum entry_type: {
    expense: "expense",
    income: "income"
  }

  enum stage: { nursery: "nursery", juvenile: "juvenile", growout: "growout", general: "general" }

  validates :entry_type, presence: true
  validates :stage, presence: true
  validates :occurred_on, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :description, presence: true

  private

  def activity_description
    description
  end
end
