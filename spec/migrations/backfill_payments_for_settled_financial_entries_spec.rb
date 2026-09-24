require "rails_helper"
require Rails.root.join("db/migrate/20260924100100_backfill_payments_for_settled_financial_entries")

RSpec.describe BackfillPaymentsForSettledFinancialEntries do
  def run_up
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  # Simula um lançamento liquidado antes de existirem pagamentos: só a data.
  def legacy_settled(settled_on:, amount_cents: 12_000)
    entry = create(:financial_entry, amount_cents: amount_cents)
    entry.payments.delete_all
    entry.update_columns(settled_on: settled_on, paid_cents: 0)
    entry
  end

  it "turns each settled entry into a full payment on its settlement date" do
    entry = legacy_settled(settled_on: Date.new(2026, 8, 10))

    expect { run_up }.to change(FinancialPayment, :count).by(1)

    expect(entry.payments.reload.sole).to have_attributes(paid_on: Date.new(2026, 8, 10), amount_cents: 12_000)
    expect(entry.reload).to have_attributes(paid_cents: 12_000, settled_on: Date.new(2026, 8, 10))
    expect(entry).to be_settled
  end

  it "leaves pending entries without payments" do
    pending_entry = create(:financial_entry)

    expect { run_up }.not_to change(FinancialPayment, :count)
    expect(pending_entry.reload.paid_cents).to eq(0)
  end

  it "does not duplicate payments when run again" do
    legacy_settled(settled_on: Date.new(2026, 8, 10))
    run_up

    expect { run_up }.not_to change(FinancialPayment, :count)
  end

  it "does not touch entries that already have payments" do
    entry = create(:financial_entry, amount_cents: 10_000)
    entry.payments.create!(paid_on: Date.new(2026, 8, 1), amount_cents: 10_000)

    expect { run_up }.not_to change(FinancialPayment, :count)
  end
end
