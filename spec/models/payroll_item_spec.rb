require "rails_helper"

RSpec.describe PayrollItem, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:payroll_item) }
  end

  it "is valid with an employee, year, month, occurred_on, item_type and a positive amount" do
    expect(build(:payroll_item)).to be_valid
  end

  it "is invalid with a zero amount" do
    item = build(:payroll_item, amount_cents: 0)

    expect(item).not_to be_valid
    expect(item.errors[:amount_cents]).to be_present
  end

  it "is invalid without an item_type" do
    item = build(:payroll_item, item_type: nil)

    expect(item).not_to be_valid
    expect(item.errors[:item_type]).to be_present
  end

  describe "creating and syncing the linked financial entry" do
    it "creates a matching financial entry on create" do
      item = create(:payroll_item, item_type: "advance", amount_cents: 50_000)

      expect(item.financial_entry).to be_present
      expect(item.financial_entry.amount_cents).to eq(50_000)
      expect(item.financial_entry.entry_type).to eq("expense")
    end

    it "updates the financial entry's amount when the item is updated" do
      item = create(:payroll_item, item_type: "advance", amount_cents: 50_000)

      item.update!(amount_cents: 75_000)

      expect(item.financial_entry.reload.amount_cents).to eq(75_000)
    end

    it "keeps a salary payment settled when its amount changes, paying the difference" do
      item = create(:payroll_item, item_type: "salary_payment", amount_cents: 50_000)

      item.update!(amount_cents: 75_000)

      entry = item.financial_entry.reload
      expect(entry).to be_settled
      expect(entry.paid_cents).to eq(75_000)
      expect(entry.payments.order(:id).map(&:amount_cents)).to eq([50_000, 25_000])
    end

    it "creates the salary payment entry already settled" do
      item = create(:payroll_item, item_type: "salary_payment", occurred_on: Date.current)

      expect(item.financial_entry).to be_settled
      expect(item.financial_entry.settled_on).to eq(Date.current)
    end

    it "creates advances (normal and 13th) pending, due on the item date, for the user to settle in the Financeiro" do
      %w[advance thirteenth_advance].each do |type|
        item = create(:payroll_item, item_type: type, amount_cents: 50_000, occurred_on: Date.new(2026, 11, 1))
        entry = item.financial_entry

        expect(entry).to be_pending
        expect(entry).to have_attributes(due_on: Date.new(2026, 11, 1), paid_cents: 0)
        expect(entry.payments).to be_empty
      end
    end

    it "keeps an advance pending when its amount changes" do
      item = create(:payroll_item, item_type: "advance", amount_cents: 50_000)

      item.update!(amount_cents: 75_000)

      entry = item.financial_entry.reload
      expect(entry).to be_pending
      expect(entry.balance_cents).to eq(75_000)
    end

    it "reopens a settled advance when its amount goes up, leaving the difference to pay" do
      item = create(:payroll_item, item_type: "advance", amount_cents: 50_000)
      item.financial_entry.settle!

      item.update!(amount_cents: 75_000)

      entry = item.financial_entry.reload
      expect(entry).to be_pending
      expect(entry).to have_attributes(paid_cents: 50_000, balance_cents: 25_000)
    end

    it "removes the financial entry when the item is destroyed" do
      item = create(:payroll_item, item_type: "advance")
      financial_entry = item.financial_entry

      item.destroy

      expect(FinancialEntry.exists?(financial_entry.id)).to be false
    end

    it "creates the financial entry for a salary payment and labels it accordingly" do
      item = create(:payroll_item, item_type: "salary_payment", amount_cents: 300_000)

      expect(item.financial_entry).to be_present
      expect(item.financial_entry.amount_cents).to eq(300_000)
      expect(item.financial_entry.description).to start_with("Pagamento salário")
    end

    it "does not create a standalone financial entry for bonuses, discounts or the base salary" do
      %w[bonus discount salary].each do |type|
        item = create(:payroll_item, item_type: type, amount_cents: 20_000)

        expect(item.financial_entry).to be_nil
      end
    end
  end

  describe "item_type scopes" do
    it "filters payroll items by item_type" do
      employee = create(:employee)
      salary = create(:payroll_item, employee: employee, item_type: "salary")
      create(:payroll_item, employee: employee, item_type: "advance")

      expect(employee.payroll_items.salary).to contain_exactly(salary)
    end
  end
end
