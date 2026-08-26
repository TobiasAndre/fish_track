class SiloStockEntry < ApplicationRecord
  belongs_to :silo
  belongs_to :feeding_type
  belongs_to :feeding_brand

  has_one :financial_entry, dependent: :destroy

  before_validation :sync_feeding_brand_from_type
  before_validation :calculate_price_per_kg_cents

  validates :occurred_on, presence: true
  validates :quantity_kg, presence: true, numericality: { greater_than: 0 }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  after_commit :sync_financial_entry!, on: %i[create update]
  after_commit :remove_financial_entry!, on: :destroy

  scope :recent_first, -> { order(occurred_on: :desc, created_at: :desc) }

  private

  def sync_feeding_brand_from_type
    self.feeding_brand = feeding_type&.feeding_brand
  end

  def calculate_price_per_kg_cents
    self.price_per_kg_cents = 0

    return if quantity_kg.blank? || quantity_kg.to_d <= 0

    self.price_per_kg_cents = (total_cents.to_i / quantity_kg.to_d).round
  end

  def sync_financial_entry!
    return if destroyed? || marked_for_destruction?

    # FinancialEntry requires a positive amount, so a zero-value entry
    # (e.g. donated ration) has nothing to log as an expense yet.
    if total_cents.to_i <= 0
      remove_financial_entry!
      return
    end

    entry = FinancialEntry.find_or_initialize_by(silo_stock_entry_id: id)
    entry.assign_attributes(
      entry_type: "expense",
      stage: "general",
      occurred_on: occurred_on,
      amount_cents: total_cents.to_i,
      description: financial_description,
      unit_id: silo&.unit_id
    )
    entry.save!
  end

  def remove_financial_entry!
    FinancialEntry.where(silo_stock_entry_id: id).delete_all
  end

  def financial_description
    feed_label = [feeding_type&.name, feeding_brand&.name].compact.join(" ")

    ["Ração (estoque)", feed_label.presence, silo&.name].compact.join(" - ")
  end
end
