require "rails_helper"
require Rails.root.join("db/migrate/20260923130100_backfill_financial_entries_for_loading_events")

RSpec.describe BackfillFinancialEntriesForLoadingEvents do
  let(:customer) { create(:customer, name: "Peixaria Azul") }

  def loading(**attrs)
    create(:stocking_event, :loading, customer: customer, price_per_kg_cents: 1_000,
      occurred_on: Date.new(2026, 8, 4), **attrs)
  end

  def run_up
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  # Simula carregamentos anteriores ao módulo financeiro: sem contas geradas.
  def forget_financial_entries
    FinancialEntry.where.not(stocking_event_id: nil).delete_all
  end

  it "creates a pending income entry for each existing loading, due on the payment date" do
    event = loading(payment_date: Date.new(2026, 9, 3))
    forget_financial_entries

    expect { run_up }.to change(FinancialEntry, :count).by(1)

    entry = FinancialEntry.find_by!(stocking_event_id: event.id)
    expect(entry).to have_attributes(
      entry_type: "income", amount_cents: 100_000, settled_on: nil,
      occurred_on: Date.new(2026, 8, 4), due_on: Date.new(2026, 9, 3),
      batch_id: event.batch_stocking.batch_id,
      unit_id: event.batch_stocking.pond.unit_id,
      stage: event.batch_stocking.batch.stage,
      description: "Carregamento - Peixaria Azul - #{event.batch_stocking.batch.name}"
    )
  end

  it "uses the loading date as due date when there is no payment date" do
    event = loading
    forget_financial_entries

    run_up

    expect(FinancialEntry.find_by!(stocking_event_id: event.id).due_on).to eq(Date.new(2026, 8, 4))
  end

  it "skips loadings with a zero total and events that are not loadings" do
    loading(price_per_kg_cents: 0)
    create(:stocking_event, :feeding)
    forget_financial_entries

    expect { run_up }.not_to change(FinancialEntry, :count)
  end

  it "does not duplicate entries when run again" do
    loading
    forget_financial_entries
    run_up

    expect { run_up }.not_to change(FinancialEntry, :count)
  end

  it "leaves loadings that already have entries untouched, keeping their settlement" do
    event = loading
    event.financial_entries.sole.update!(settled_on: Date.new(2026, 8, 5))

    expect { run_up }.not_to change(FinancialEntry, :count)
    expect(event.financial_entries.sole.settled_on).to eq(Date.new(2026, 8, 5))
  end

  it "removes only the loading entries on rollback" do
    loading
    other = create(:financial_entry, entry_type: "expense")

    ActiveRecord::Migration.suppress_messages { described_class.new.down }

    expect(FinancialEntry.where.not(stocking_event_id: nil)).to be_empty
    expect(FinancialEntry.exists?(other.id)).to be(true)
  end
end
