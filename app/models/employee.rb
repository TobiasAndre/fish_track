class Employee < ApplicationRecord
  belongs_to :company
  has_many :payroll_items, dependent: :destroy

  validates :name, presence: true
end
