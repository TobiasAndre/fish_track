require "rails_helper"

RSpec.describe PayrollStatement do
  let(:employee) { create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10)) }

  def item(type, cents, **attrs)
    create(:payroll_item, employee: employee, year: 2026, month: 9, item_type: type, amount_cents: cents, occurred_on: Date.new(2026, 9, 10), **attrs)
  end

  it "adds bonuses to the salary and takes out advances and discounts, ignoring the 13th advance" do
    item("bonus", 20_000)
    item("advance", 50_000)
    item("discount", 10_000)
    item("thirteenth_advance", 100_000)

    statement = described_class.new(employee, year: 2026, month: 9)

    expect(statement).to have_attributes(
      salary_cents: 300_000, earnings_cents: 320_000, deductions_cents: 60_000, remaining_cents: 260_000,
      total_thirteenth_advance_cents: 100_000, paid_cents: 0, outstanding_cents: 260_000, competence_label: "09/2026"
    )
  end

  it "reduces the balance by the salary payment" do
    item("salary_payment", 200_000)

    statement = described_class.new(employee, year: 2026, month: 9)

    expect(statement).to have_attributes(remaining_cents: 300_000, paid_cents: 200_000, outstanding_cents: 100_000)
  end

  it "never goes below zero" do
    item("advance", 400_000)

    expect(described_class.new(employee, year: 2026, month: 9).remaining_cents).to eq(0)
  end

  it "zeroes the base salary in the month of the termination" do
    employee.update!(status: "terminated", terminated_on: Date.new(2026, 9, 20))

    statement = described_class.new(employee, year: 2026, month: 9)

    expect(statement).to be_terminated_this_month
    expect(statement.salary_cents).to eq(0)
  end

  it "only takes the items of its own competência" do
    item("advance", 50_000)
    create(:payroll_item, employee: employee, year: 2026, month: 10, item_type: "advance", amount_cents: 70_000)

    expect(described_class.new(employee, year: 2026, month: 9).total_advance_cents).to eq(50_000)
  end
end
