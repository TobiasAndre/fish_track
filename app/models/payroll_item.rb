class PayrollItem < ApplicationRecord
  belongs_to :employee

  has_one :financial_entry, dependent: :destroy

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :year, :month, :occurred_on, :item_type, presence: true

  scope :salary, -> { where(item_type: "salary") }
  scope :advance, -> { where(item_type: "advance") }
  scope :bonus, -> { where(item_type: "bonus") }
  scope :discount, -> { where(item_type: "discount") }

  after_create :create_financial_entry!
  after_update :sync_financial_entry!
  after_destroy :remove_financial_entry!

  private

  def create_financial_entry!
    FinancialEntry.create!(
      entry_type: "expense",
      stage: "general",
      occurred_on: occurred_on,
      amount_cents: amount_cents,
      description: financial_description,
      notes: notes,
      payroll_item_id: id
    )
  end

  def sync_financial_entry!
    return unless financial_entry

    financial_entry.update!(
      occurred_on: occurred_on,
      amount_cents: amount_cents,
      description: financial_description,
      notes: notes
    )
  end

  def remove_financial_entry!
    FinancialEntry.where(payroll_item_id: id).delete_all
  end

  def financial_description
    prefix =
      case item_type
      when "advance" then "Adiantamento"
      when "bonus" then "Bônus"
      when "discount" then "Desconto"
      when "salary_payment" then "Pagamento salário"
      else "Folha"
      end

    "#{prefix} - #{employee.name} (#{month}/#{year})"
  end
end
