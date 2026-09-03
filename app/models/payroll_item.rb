class PayrollItem < ApplicationRecord
  include Loggable

  belongs_to :employee

  has_one :financial_entry, dependent: :destroy

  # Tipos que representam uma saída de caixa e, por isso, geram um lançamento no
  # financeiro. Bônus e descontos NÃO entram sozinhos: eles já estão embutidos no
  # valor líquido do "Pagamento de salário" (salary_payment). Lançar bônus/desconto
  # como despesa própria além do salary_payment duplicaria (bônus) ou inflaria
  # indevidamente (desconto) as despesas de folha.
  FINANCIAL_ENTRY_ITEM_TYPES = %w[advance thirteenth_advance salary_payment].freeze

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :year, :month, :occurred_on, :item_type, presence: true

  scope :salary, -> { where(item_type: "salary") }
  scope :advance, -> { where(item_type: "advance") }
  scope :thirteenth_advance, -> { where(item_type: "thirteenth_advance") }
  scope :bonus, -> { where(item_type: "bonus") }
  scope :discount, -> { where(item_type: "discount") }
  scope :salary_payment, -> { where(item_type: "salary_payment") }

  after_create :create_financial_entry!, if: :generates_financial_entry?
  after_update :sync_financial_entry!
  after_destroy :remove_financial_entry!

  private

  def activity_description
    financial_description
  end

  def generates_financial_entry?
    FINANCIAL_ENTRY_ITEM_TYPES.include?(item_type)
  end

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
      when "thirteenth_advance" then "Adiantamento 13º"
      when "bonus" then "Bônus"
      when "discount" then "Desconto"
      when "salary_payment" then "Pagamento salário"
      else "Folha"
      end

    base = "#{prefix} - #{employee.name} (#{month}/#{year})"
    installment_number && installments_count ? "#{base} — parcela #{installment_number}/#{installments_count}" : base
  end
end
