class FinancialPayment < ApplicationRecord
  include Loggable

  belongs_to :financial_entry, inverse_of: :payments

  validates :paid_on, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :paid_on_not_in_the_future
  validate :amount_within_balance, on: :create

  after_save :recalculate_entry_settlement
  after_destroy :recalculate_entry_settlement, unless: :destroyed_by_association

  private

  def recalculate_entry_settlement
    financial_entry.recalculate_settlement!
  end

  def paid_on_not_in_the_future
    return if paid_on.blank? || paid_on <= Date.current

    errors.add(:paid_on, "não pode ser uma data futura (o pagamento já teria acontecido)")
  end

  def amount_within_balance
    return if financial_entry.blank? || amount_cents.to_i <= 0
    return if amount_cents <= financial_entry.balance_cents

    errors.add(:amount_cents, "excede o saldo em aberto (#{helpers.number_to_currency(financial_entry.balance_cents / 100.0)})")
  end

  def helpers
    ApplicationController.helpers
  end

  def activity_description
    verb = financial_entry&.receivable? ? "Recebimento" : "Pagamento"
    "#{verb} de #{helpers.number_to_currency(amount_cents.to_i / 100.0)} - #{financial_entry&.description}"
  end
end
