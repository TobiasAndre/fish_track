require "rails_helper"

RSpec.describe FinancialEntry, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:financial_entry) }
  end

  it "is valid with entry_type, stage, occurred_on, a positive amount and a description" do
    expect(build(:financial_entry)).to be_valid
  end

  it "is invalid without an entry_type" do
    entry = build(:financial_entry, entry_type: nil)

    expect(entry).not_to be_valid
    expect(entry.errors[:entry_type]).to be_present
  end

  it "is invalid without a description" do
    entry = build(:financial_entry, description: nil)

    expect(entry).not_to be_valid
    expect(entry.errors[:description]).to be_present
  end

  it "is invalid with a zero or negative amount" do
    entry = build(:financial_entry, amount_cents: 0)

    expect(entry).not_to be_valid
    expect(entry.errors[:amount_cents]).to be_present
  end

  it "is valid without a batch or a unit" do
    entry = build(:financial_entry, batch: nil, unit: nil)

    expect(entry).to be_valid
  end

  describe "entry_type enum" do
    it "exposes predicate methods for expense and income" do
      expect(build(:financial_entry, entry_type: "expense")).to be_expense
      expect(build(:financial_entry, entry_type: "income")).to be_income
    end
  end
end
