class Company < ApplicationRecord
  has_many :users, dependent: :nullify

  has_many :units, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :financial_entries, dependent: :destroy
  has_many :payroll_items, dependent: :destroy

  has_many :ponds, through: :units
  has_many :batches, through: :ponds
  has_many :batch_events, through: :batches
end
