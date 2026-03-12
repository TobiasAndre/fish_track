class Product < ApplicationRecord
  UNITS = %w[kg un caixa saco litro].freeze

  validates :name, presence: true
  validates :sku, uniqueness: true, allow_blank: true
  validates :unit, presence: true, inclusion: { in: UNITS }
end
