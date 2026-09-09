require "rails_helper"

RSpec.describe Payroll::CreateItem do
  let(:employee) { create(:employee, name: "Maria") }

  def build_item(item_type:, year: 2026, month: 3, amount_cents: 150_000)
    build(:payroll_item, employee: employee, item_type: item_type, year: year, month: month, amount_cents: amount_cents)
  end

  describe ".call!" do
    it "does nothing for discount items" do
      item = build_item(item_type: "discount")

      expect { described_class.call!(item) }.not_to change(FinancialEntry, :count)
    end

    it "creates a settled expense entry dated on the 28th of the competence month" do
      item = build_item(item_type: "salary", year: 2026, month: 3, amount_cents: 250_000)

      expect { described_class.call!(item) }.to change(FinancialEntry, :count).by(1)

      entry = FinancialEntry.last
      expect(entry).to have_attributes(
        entry_type: "expense",
        stage: "general",
        occurred_on: Date.new(2026, 3, 28),
        due_on: Date.new(2026, 3, 28),
        settled_on: Date.new(2026, 3, 28),
        amount_cents: 250_000,
        description: "Salário - Maria"
      )
    end

    it "never settles the entry in the future" do
      future = Date.current.next_month
      item = build_item(item_type: "advance", year: future.year, month: future.month)

      described_class.call!(item)

      expect(FinancialEntry.last.settled_on).to eq(Date.current)
    end

    it "labels advance items" do
      described_class.call!(build_item(item_type: "advance"))

      expect(FinancialEntry.last.description).to eq("Adiantamento salarial - Maria")
    end

    it "labels bonus items" do
      described_class.call!(build_item(item_type: "bonus"))

      expect(FinancialEntry.last.description).to eq("Bônus - Maria")
    end
  end
end
