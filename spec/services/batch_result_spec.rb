require "rails_helper"

RSpec.describe BatchResult do
  let!(:batch_a) { create(:batch, name: "Lote A", started_on: Date.new(2026, 1, 1)) }
  let!(:batch_b) { create(:batch, name: "Lote B", started_on: Date.new(2026, 6, 1), status: "closed") }

  def entry(batch, type, cents, on: Date.new(2026, 8, 10), paid: 0)
    create(:financial_entry, batch: batch, entry_type: type, amount_cents: cents, occurred_on: on).tap do |e|
      e.payments.create!(paid_on: Date.current, amount_cents: paid) if paid.positive?
    end
  end

  it "computes revenue, cost, result and margin per batch" do
    entry(batch_a, "income", 100_000)
    entry(batch_a, "income", 50_000)
    entry(batch_a, "expense", 90_000)

    row = described_class.new.rows.sole

    expect(row.batch).to eq(batch_a)
    expect(row).to have_attributes(revenue_cents: 150_000, cost_cents: 90_000, result_cents: 60_000)
    expect(row.margin_percent).to eq(40.0)
  end

  it "has no margin when there is no revenue, and reports a negative result" do
    entry(batch_a, "expense", 30_000)

    row = described_class.new.rows.sole

    expect(row.result_cents).to eq(-30_000)
    expect(row.margin_percent).to be_nil
  end

  it "reports a negative margin for a losing batch" do
    entry(batch_a, "income", 100_000)
    entry(batch_a, "expense", 130_000)

    expect(described_class.new.rows.sole.margin_percent).to eq(-30.0)
  end

  it "separates what was already received/paid (cash) from the accrued totals" do
    entry(batch_a, "income", 100_000, paid: 40_000)
    entry(batch_a, "expense", 80_000, paid: 80_000)

    row = described_class.new.rows.sole

    expect(row).to have_attributes(received_cents: 40_000, paid_cents: 80_000, cash_result_cents: -40_000)
    expect(row.receivable_cents).to eq(60_000)
    expect(row.payable_cents).to eq(0)
  end

  it "never counts more than the entry amount as paid (overpayment after an edit)" do
    e = entry(batch_a, "income", 100_000, paid: 100_000)
    e.update_columns(amount_cents: 60_000)

    expect(described_class.new.rows.sole.received_cents).to eq(60_000)
  end

  it "orders batches from the most recent to the oldest and totals them" do
    entry(batch_a, "income", 100_000)
    entry(batch_a, "expense", 40_000)
    entry(batch_b, "income", 50_000)
    entry(batch_b, "expense", 60_000)

    result = described_class.new

    expect(result.rows.map(&:batch)).to eq([batch_b, batch_a])
    expect(result.total).to have_attributes(revenue_cents: 150_000, cost_cents: 100_000, result_cents: 50_000)
    expect(result.total.margin_percent).to be_within(0.1).of(33.3)
  end

  it "filters by batch status" do
    entry(batch_a, "income", 1_000)
    entry(batch_b, "income", 1_000)

    expect(described_class.new(status: "active").rows.map(&:batch)).to eq([batch_a])
    expect(described_class.new(status: "closed").rows.map(&:batch)).to eq([batch_b])
    expect(described_class.new(status: "bogus").rows.size).to eq(2)
  end

  it "filters by competence date" do
    entry(batch_a, "income", 100_000, on: Date.new(2026, 7, 31))
    entry(batch_a, "income", 25_000, on: Date.new(2026, 8, 15))

    result = described_class.new(from: "2026-08-01", to: "2026-08-31")

    expect(result.rows.sole.revenue_cents).to eq(25_000)
  end

  it "ignores an invalid date instead of failing" do
    entry(batch_a, "income", 1_000)

    expect(described_class.new(from: "not-a-date").rows.size).to eq(1)
  end

  it "keeps entries without a batch out of the batch results but reports them" do
    entry(batch_a, "income", 100_000)
    create(:financial_entry, batch: nil, entry_type: "expense", amount_cents: 70_000, occurred_on: Date.new(2026, 8, 10))

    result = described_class.new

    expect(result.total.cost_cents).to eq(0)
    expect(result.unallocated).to have_attributes(revenue_cents: 0, cost_cents: 70_000)
  end

  it "skips batches with no entries in the period and counts them" do
    entry(batch_a, "income", 1_000)

    result = described_class.new

    expect(result.rows.map(&:batch)).to eq([batch_a])
    expect(result.batches_without_entries_count).to eq(1)
  end
end
