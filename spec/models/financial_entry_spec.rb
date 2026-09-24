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

  describe "settlement (contas a pagar/receber)" do
    it "defaults due_on to occurred_on when blank" do
      entry = create(:financial_entry, occurred_on: Date.new(2026, 3, 10), due_on: nil)

      expect(entry.due_on).to eq(Date.new(2026, 3, 10))
    end

    it "keeps an explicit due_on" do
      entry = create(:financial_entry, occurred_on: Date.new(2026, 3, 10), due_on: Date.new(2026, 4, 9))

      expect(entry.due_on).to eq(Date.new(2026, 4, 9))
    end

    it "starts pending when settled_on is nil" do
      entry = build(:financial_entry, settled_on: nil)

      expect(entry).to be_pending
      expect(entry).not_to be_settled
    end

    it "#settle! records the settlement date and is idempotent" do
      entry = create(:financial_entry, settled_on: nil)

      entry.settle!(Date.new(2026, 5, 1))
      expect(entry.reload.settled_on).to eq(Date.new(2026, 5, 1))
      expect(entry).to be_settled

      entry.settle!(Date.new(2026, 6, 1))
      expect(entry.reload.settled_on).to eq(Date.new(2026, 5, 1))
    end

    it "is invalid with a settled_on in the future" do
      entry = build(:financial_entry, settled_on: Date.current.next_month)

      expect(entry).not_to be_valid
      expect(entry.errors[:settled_on]).to be_present
    end

    it "#settle! clamps a future date down to today" do
      entry = create(:financial_entry, settled_on: nil)

      entry.settle!(Date.current.next_year)

      expect(entry.reload.settled_on).to eq(Date.current)
    end

    it "#unsettle! clears the settlement date" do
      entry = create(:financial_entry, settled_on: Date.current)

      entry.unsettle!

      expect(entry.reload.settled_on).to be_nil
      expect(entry).to be_pending
    end

    it "#overdue? is true only for pending entries past their due date" do
      overdue = build(:financial_entry, due_on: Date.current.prev_day, settled_on: nil)
      future  = build(:financial_entry, due_on: Date.current.next_day, settled_on: nil)
      settled = build(:financial_entry, due_on: Date.current.prev_day, settled_on: Date.current)

      expect(overdue).to be_overdue
      expect(future).not_to be_overdue
      expect(settled).not_to be_overdue
    end

    describe "scopes" do
      let!(:pending_future) { create(:financial_entry, due_on: Date.current.next_month, settled_on: nil) }
      let!(:pending_overdue) { create(:financial_entry, due_on: Date.current.prev_day, settled_on: nil) }
      let!(:already_settled) { create(:financial_entry, settled_on: Date.current) }

      it "filters pending / settled / overdue" do
        expect(FinancialEntry.pending).to match_array([pending_future, pending_overdue])
        expect(FinancialEntry.settled).to contain_exactly(already_settled)
        expect(FinancialEntry.overdue).to contain_exactly(pending_overdue)
      end
    end
  end

  describe "payments" do
    it "creates a full payment when born with a settled_on (e.g. payroll)" do
      entry = create(:financial_entry, amount_cents: 20_000, settled_on: Date.current.prev_day)

      expect(entry.payments.sole).to have_attributes(amount_cents: 20_000, paid_on: Date.current.prev_day)
      expect(entry.reload).to have_attributes(paid_cents: 20_000, settled_on: Date.current.prev_day)
    end

    it "#settle! pays only the remaining balance of a partially paid entry" do
      entry = create(:financial_entry, amount_cents: 100_000)
      entry.payments.create!(paid_on: Date.current.prev_day, amount_cents: 40_000)

      entry.settle!(Date.current)

      expect(entry.payments.order(:id).map(&:amount_cents)).to eq([40_000, 60_000])
      expect(entry.reload).to be_settled
    end

    it "#unsettle! removes every payment and reopens the entry" do
      entry = create(:financial_entry, amount_cents: 100_000)
      entry.payments.create!(paid_on: Date.current, amount_cents: 40_000)
      entry.settle!

      entry.unsettle!

      expect(entry.payments).to be_empty
      expect(entry.reload).to have_attributes(paid_cents: 0, settled_on: nil)
    end

    it "reopens a settled entry when its amount increases, leaving the difference as balance" do
      entry = create(:financial_entry, amount_cents: 100_000)
      entry.settle!

      entry.update!(amount_cents: 150_000)

      entry.reload
      expect(entry).to be_pending
      expect(entry).to be_partially_paid
      expect(entry.balance_cents).to eq(50_000)
    end

    it "settles a partially paid entry when its amount drops to what was already paid" do
      entry = create(:financial_entry, amount_cents: 100_000)
      entry.payments.create!(paid_on: Date.current, amount_cents: 60_000)

      entry.update!(amount_cents: 60_000)

      expect(entry.reload).to be_settled
    end

    it "removes its payments when destroyed" do
      entry = create(:financial_entry)
      entry.settle!

      expect { entry.destroy! }.to change(FinancialPayment, :count).by(-1)
    end

    it "removes its payments even when deleted without callbacks (delete_all flows)" do
      entry = create(:financial_entry)
      entry.settle!

      expect { FinancialEntry.where(id: entry.id).delete_all }.to change(FinancialPayment, :count).by(-1)
    end

    it ".partially_paid only returns pending entries with something paid" do
      partial = create(:financial_entry, amount_cents: 100_000)
      partial.payments.create!(paid_on: Date.current, amount_cents: 10_000)
      settled = create(:financial_entry).tap(&:settle!)
      untouched = create(:financial_entry)

      expect(FinancialEntry.partially_paid).to contain_exactly(partial)
      expect(FinancialEntry.pending).to include(partial, untouched)
      expect(FinancialEntry.pending).not_to include(settled)
    end

    it ".open_balance_cents sums what is still owed, not the full amounts" do
      partial = create(:financial_entry, amount_cents: 100_000)
      partial.payments.create!(paid_on: Date.current, amount_cents: 30_000)
      create(:financial_entry, amount_cents: 20_000)

      expect(FinancialEntry.pending.open_balance_cents).to eq(70_000 + 20_000)
    end
  end
end
