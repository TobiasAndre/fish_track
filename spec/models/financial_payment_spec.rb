require "rails_helper"

RSpec.describe FinancialPayment, type: :model do
  let(:entry) { create(:financial_entry, amount_cents: 100_000, due_on: Date.current) }

  def pay(amount_cents, on: Date.current, target: entry)
    target.payments.create!(paid_on: on, amount_cents: amount_cents)
  end

  it "keeps a partially paid entry pending, with the paid amount and remaining balance" do
    pay(30_000)

    entry.reload
    expect(entry).to have_attributes(paid_cents: 30_000, settled_on: nil)
    expect(entry).to be_pending
    expect(entry).to be_partially_paid
    expect(entry.balance_cents).to eq(70_000)
  end

  it "settles the entry on the date of the payment that completes it" do
    pay(30_000, on: Date.current.prev_day)
    pay(70_000, on: Date.current)

    entry.reload
    expect(entry).to be_settled
    expect(entry).not_to be_partially_paid
    expect(entry.settled_on).to eq(Date.current)
    expect(entry.paid_cents).to eq(100_000)
    expect(entry.balance_cents).to eq(0)
  end

  it "reopens the entry when a payment is removed" do
    pay(60_000)
    last = pay(40_000)
    expect(entry.reload).to be_settled

    last.destroy!

    entry.reload
    expect(entry).to be_pending
    expect(entry.paid_cents).to eq(60_000)
    expect(entry).to be_partially_paid
  end

  it "is invalid with a non-positive amount" do
    payment = entry.payments.build(paid_on: Date.current, amount_cents: 0)

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end

  it "is invalid without a date or with a future date" do
    expect(entry.payments.build(amount_cents: 100)).not_to be_valid

    future = entry.payments.build(paid_on: Date.current.next_day, amount_cents: 100)
    expect(future).not_to be_valid
    expect(future.errors[:paid_on]).to be_present
  end

  it "rejects a payment above the remaining balance" do
    pay(80_000)

    payment = entry.payments.build(paid_on: Date.current, amount_cents: 30_000)

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents].first).to include("excede o saldo")
  end

  it "does not touch the paid total when an invalid payment is rejected" do
    entry.payments.create(paid_on: Date.current, amount_cents: 999_999)

    expect(entry.reload.paid_cents).to eq(0)
  end

  it "logs who registered the payment" do
    Current.user = create(:user)

    pay(25_000)

    log = ActivityLog.where(resource_type: "FinancialPayment").last
    expect(log.description).to include("Pagamento de", entry.description)
    expect(log.action).to eq("create")
  end

  it "labels a payment on an income entry as a receipt" do
    Current.user = create(:user)
    income = create(:financial_entry, entry_type: "income", amount_cents: 50_000)

    pay(10_000, target: income)

    expect(ActivityLog.where(resource_type: "FinancialPayment").last.description).to start_with("Recebimento de")
  end
end
