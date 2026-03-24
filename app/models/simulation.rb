class Simulation < ApplicationRecord
  belongs_to :customer
  belongs_to :integrated, optional: true

  has_many :simulation_products, dependent: :destroy
  has_many :products, through: :simulation_products

  accepts_nested_attributes_for :simulation_products, allow_destroy: true, reject_if: :all_blank

  before_validation :normalize_numeric_fields
  before_validation :calculate_totals

  validates :simulated_on, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :avg_weight_kg, numericality: { greater_than: 0 }
  validates :price_per_kg_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :thousand_value_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :loading_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :freight_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :loading_count, numericality: { greater_than: 0, only_integer: true }

  private

  def normalize_numeric_fields
    raw_quantity = read_attribute_before_type_cast("quantity")
    self.quantity = raw_quantity.to_s.gsub(/\D/, "").to_i if raw_quantity.present?

    raw_loading_count = read_attribute_before_type_cast("loading_count")
    self.loading_count = raw_loading_count.to_s.gsub(/\D/, "").to_i if raw_loading_count.present?

    raw_avg_weight = read_attribute_before_type_cast("avg_weight_kg")
    self.avg_weight_kg = normalize_decimal(raw_avg_weight) if raw_avg_weight.present?

    raw_total_weight = read_attribute_before_type_cast("total_weight_kg")
    self.total_weight_kg = normalize_decimal(raw_total_weight) if raw_total_weight.present?
  end

  def normalize_decimal(value)
    string = value.to_s.strip

    if string.include?(",")
      string.gsub(".", "").tr(",", ".")
    else
      string
    end
  end

  def calculate_totals
    self.total_weight_kg = quantity.to_i * avg_weight_kg.to_d

    fish_total_cents =
      (
        (avg_weight_kg.to_d * price_per_kg_cents.to_i * 1000) +
        thousand_value_cents.to_i
      ) * (quantity.to_d / 1000)

    self.total_cents =
      fish_total_cents.to_i +
      loading_cost_cents.to_i +
      freight_cost_cents.to_i
  end
end
