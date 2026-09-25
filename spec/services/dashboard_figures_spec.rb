require "rails_helper"

RSpec.describe DashboardFigures do
  let!(:pond_a) { create(:pond, name: "Tanque A") }
  let!(:pond_b) { create(:pond, name: "Tanque B") }
  let!(:batch_a) { create(:batch, pond: pond_a, stocking_quantity: 1_000) }
  let!(:batch_b) { create(:batch, pond: pond_b, stocking_quantity: 2_500) }
  let!(:closed) { create(:batch, status: "closed", stocking_quantity: 9_999) }

  def loading(batch, quantity)
    stocking = batch.batch_stockings.first
    create(:stocking_event, :loading, batch_stocking: stocking, quantity: quantity).tap { |e| e.update_columns(quantity: quantity) }
  end

  def entry(batch, type, cents)
    create(:financial_entry, batch: batch, entry_type: type, amount_cents: cents)
  end

  subject(:figures) { described_class.new([batch_a, batch_b]) }

  it "sums the stocked quantity of the given batches only" do
    expect(figures.stocked_quantity).to eq(3_500)
  end

  it "sums the loaded quantity (delivered fish) per batch and in total" do
    loading(batch_a, 300)
    loading(batch_a, 200)
    loading(batch_b, 100)
    loading(closed, 5_000) # lote encerrado: fora dos números

    expect(figures.for(batch_a).loaded_quantity).to eq(500)
    expect(figures.for(batch_b).loaded_quantity).to eq(100)
    expect(figures.delivered_quantity).to eq(600)
  end

  it "ignores events that are not loadings" do
    create(:stocking_event, :mortality, batch_stocking: batch_a.batch_stockings.first, quantity: 50)

    expect(figures.delivered_quantity).to eq(0)
  end

  it "sums expense and revenue per batch and in total from the Financeiro entries linked to the batches" do
    entry(batch_a, "expense", 10_000)
    entry(batch_a, "expense", 5_000)
    entry(batch_a, "income", 40_000)
    entry(batch_b, "income", 7_000)
    entry(closed, "expense", 99_999)
    create(:financial_entry, batch: nil, entry_type: "expense", amount_cents: 88_888)

    expect(figures.for(batch_a)).to have_attributes(expense_cents: 15_000, revenue_cents: 40_000)
    expect(figures.for(batch_b)).to have_attributes(expense_cents: 0, revenue_cents: 7_000)
    expect(figures.expense_cents).to eq(15_000)
    expect(figures.revenue_cents).to eq(47_000)
  end

  it "computes peixes a entregar as alojados minus entregues" do
    loading(batch_a, 300)
    loading(batch_b, 500)

    expect(figures.to_deliver_quantity).to eq(3_500 - 800)
  end

  it "computes the saldo financeiro as revenue minus expense" do
    entry(batch_a, "income", 50_000)
    entry(batch_b, "expense", 20_000)
    entry(closed, "income", 999_999)

    expect(figures.balance_cents).to eq(30_000)
  end

  it "lets the saldo go negative" do
    entry(batch_a, "expense", 9_000)

    expect(figures.balance_cents).to eq(-9_000)
  end

  it "returns zeros for a batch without movement" do
    expect(figures.for(batch_a)).to have_attributes(loaded_quantity: 0, expense_cents: 0, revenue_cents: 0)
  end

  it "handles an empty list of batches" do
    empty = described_class.new([])

    expect([empty.stocked_quantity, empty.delivered_quantity, empty.to_deliver_quantity, empty.expense_cents, empty.revenue_cents, empty.balance_cents]).to eq([0, 0, 0, 0, 0, 0])
  end

  it "runs a fixed number of queries regardless of how many batches there are" do
    3.times { create(:batch, stocking_quantity: 10) }
    batches = Batch.where(status: "active").to_a
    figures = described_class.new(batches)

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql].start_with?("SET ") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      figures.stocked_quantity
      figures.delivered_quantity
      figures.expense_cents
      figures.revenue_cents
      batches.each { |b| figures.for(b) }
    end

    expect(queries).to be <= 3
  end
end
