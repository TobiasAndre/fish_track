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
      item = create(:payroll_item, amount_cents: 50_000)

      item.update!(amount_cents: 75_000)

      expect(item.financial_entry.reload.amount_cents).to eq(75_000)
    end

    it "removes the financial entry when the item is destroyed" do
      item = create(:payroll_item)
      financial_entry = item.financial_entry

      item.destroy

      expect(FinancialEntry.exists?(financial_entry.id)).to be false
    end

    it "labels a bonus's financial entry description accordingly" do
      item = create(:payroll_item, item_type: "bonus")

      expect(item.financial_entry.description).to start_with("Bônus")
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
