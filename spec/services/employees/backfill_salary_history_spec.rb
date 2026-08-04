require "rails_helper"

RSpec.describe Employees::BackfillSalaryHistory, type: :model do
  it "creates an initial record for an employee with no salary history" do
    employee = create(:employee, salary_cents: 250_000, started_on: Date.new(2023, 3, 1))
    employee.salary_changes.destroy_all # simulate a pre-existing employee from before this feature existed

    expect { described_class.call }.to change { employee.salary_changes.count }.by(1)

    record = employee.salary_changes.reload.first
    expect(record.change_type).to eq("initial")
    expect(record.previous_salary_cents).to be_nil
    expect(record.salary_cents).to eq(250_000)
    expect(record.effective_on).to eq(Date.new(2023, 3, 1))
  end

  it "is idempotent: running it twice does not duplicate records" do
    employee = create(:employee)
    employee.salary_changes.destroy_all

    described_class.call
    expect { described_class.call }.not_to change { employee.salary_changes.count }
  end

  it "does not touch employees that already have history" do
    employee = create(:employee) # already has its auto-created initial record

    expect { described_class.call }.not_to change { employee.salary_changes.count }
  end

  it "returns the number of records created" do
    employee = create(:employee)
    employee.salary_changes.destroy_all

    expect(described_class.call).to eq(1)
  end
end
