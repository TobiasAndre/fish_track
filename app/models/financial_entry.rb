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

  before_validation :default_due_on

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

  # Marca o lançamento como liquidado (baixa). Idempotente: se já estiver
  # liquidado, mantém a data original. Uma baixa não pode estar no futuro,
  # então uma data futura é limitada a hoje.
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

    update!(settled_on: effective)
  end

  # Reabre um lançamento liquidado (estorna a baixa).
  def unsettle!
    return true if pending?

    update!(settled_on: nil)
  end

  private

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
