class Product < ApplicationRecord
  include Loggable

  has_many :simulation_products, dependent: :destroy
  has_many :simulations, through: :simulation_products

  UNITS = %w[kg un caixa saco litro].freeze

  validates :name, presence: true
  validates :sku, uniqueness: true, allow_blank: true
  validates :unit, presence: true, inclusion: { in: UNITS }

  private

  def activity_description
    "Produto #{name}"
  end
end
