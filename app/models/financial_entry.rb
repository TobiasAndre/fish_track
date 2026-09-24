class FinancialEntry < ApplicationRecord
  include Loggable

  belongs_to :batch, optional: true
  belongs_to :unit, optional: true # útil quando é "Geral Sede" sem lote
  belongs_to :silo_stock_entry, optional: true
  belongs_to :stocking_event, optional: true

  # Pagamentos/recebimentos (parciais ou não). settled_on e paid_cents são
  # derivados deles (ver recalculate_settlement!).
  has_many :payments, class_name: "FinancialPayment", dependent: :destroy, inverse_of: :financial_entry

  enum :entry_type, {
    expense: "expense",
    income: "income"
  }

  enum :stage, { nursery: "nursery", juvenile: "juvenile", growout: "growout", general: "general" }

  before_validation :default_due_on
  after_create :register_payment_for_direct_settlement
  after_update :recalculate_settlement!, if: :saved_change_to_amount_cents?

  validates :entry_type, presence: true
  validates :stage, presence: true
  validates :occurred_on, presence: true
  validates :due_on, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :description, presence: true
  validate :settled_on_not_in_the_future

  # Situação de liquidação (contas a pagar/receber).
  scope :settled, -> { where.not(settled_on: nil) }
  scope :pending, -> { where(settled_on: nil) }
  scope :overdue, -> { pending.where(due_on: ..Date.current.prev_day) }
  scope :partially_paid, -> { pending.where("financial_entries.paid_cents > 0") }

  # Saldo em aberto de um recorte (valor - já pago), para totais de contas a
  # pagar/receber.
  def self.open_balance_cents
    sum("GREATEST(financial_entries.amount_cents - financial_entries.paid_cents, 0)").to_i
  end

  # "A pagar" = despesas; "a receber" = entradas.
  scope :payable, -> { where(entry_type: "expense") }
  scope :receivable, -> { where(entry_type: "income") }

  def settled?
    settled_on.present?
  end

  def pending?
    !settled?
  end

  def overdue?
    pending? && due_on.present? && due_on < Date.current
  end

  def payable?
    expense?
  end

  def receivable?
    income?
  end

  def partially_paid?
    pending? && paid_cents.to_i.positive?
  end

  def balance_cents
    [amount_cents.to_i - paid_cents.to_i, 0].max
  end

  # Liquida o que falta: registra um pagamento do saldo em aberto. Idempotente:
  # se já estiver liquidado, mantém tudo como está. Uma baixa não pode estar no
  # futuro, então uma data futura é limitada a hoje.
  def settle!(date = Date.current)
    return true if settled?

    effective =
      begin
        parsed = date.presence || Date.current
        parsed.respond_to?(:to_date) ? parsed.to_date : Date.current
      rescue ArgumentError, TypeError
        Date.current
      end
    effective = Date.current if effective > Date.current

    payments.create!(paid_on: effective, amount_cents: balance_cents)
    true
  end

  # Reabre o lançamento: remove todos os pagamentos e volta para em aberto.
  def unsettle!
    return true if pending? && paid_cents.to_i.zero?

    payments.destroy_all
    recalculate_settlement!
    true
  end

  # Mantém paid_cents (total pago) e settled_on (data do pagamento que quitou)
  # coerentes com os pagamentos. Usa update_columns de propósito: é cache
  # derivado e não deve disparar validações nem log de atividade.
  def recalculate_settlement!
    paid = payments.sum(:amount_cents)
    fully_paid = paid.positive? && paid >= amount_cents.to_i

    update_columns(
      paid_cents: paid,
      settled_on: fully_paid ? payments.maximum(:paid_on) : nil,
      updated_at: Time.current
    )
  end

  private

  # Quem cria um lançamento já com settled_on (ex.: folha, que só é lançada
  # depois de paga) ganha o pagamento integral correspondente.
  def register_payment_for_direct_settlement
    return if settled_on.blank? || payments.exists?

    payments.create!(paid_on: settled_on, amount_cents: amount_cents)
  end

  def default_due_on
    self.due_on ||= occurred_on
  end

  def settled_on_not_in_the_future
    return if settled_on.blank?
    return if settled_on <= Date.current

    errors.add(:settled_on, "não pode ser uma data futura (a baixa já teria acontecido)")
  end

  def activity_description
    description
  end
end
