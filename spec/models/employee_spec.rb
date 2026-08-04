require "rails_helper"

RSpec.describe Employee, type: :model do
  it "is valid with a name and a non-negative salary" do
    expect(build(:employee)).to be_valid
  end

  it "is invalid without a name" do
    employee = build(:employee, name: nil)

    expect(employee).not_to be_valid
    expect(employee.errors[:name]).to be_present
  end

  it "is invalid with a negative salary" do
    employee = build(:employee, salary_cents: -1)

    expect(employee).not_to be_valid
    expect(employee.errors[:salary_cents]).to be_present
  end

  describe "#payroll_balance" do
    it "nets salary and bonuses against advances and discounts for the given month" do
      employee = create(:employee)
      create(:payroll_item, employee: employee, item_type: "salary", amount_cents: 500_000, year: 2026, month: 6)
      create(:payroll_item, employee: employee, item_type: "advance", amount_cents: 50_000, year: 2026, month: 6)
      create(:payroll_item, employee: employee, item_type: "bonus", amount_cents: 20_000, year: 2026, month: 6)
      create(:payroll_item, employee: employee, item_type: "discount", amount_cents: 10_000, year: 2026, month: 6)
      # a payroll item from a different month must not be included
      create(:payroll_item, employee: employee, item_type: "salary", amount_cents: 999_999, year: 2026, month: 5)

      balance = employee.payroll_balance(year: 2026, month: 6)

      expect(balance).to eq(
        salary_cents: 500_000,
        advances_cents: 50_000,
        bonuses_cents: 20_000,
        discounts_cents: 10_000,
        net_to_pay_cents: 460_000
      )
    end
  end
end
