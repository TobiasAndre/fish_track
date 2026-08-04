require "rails_helper"

RSpec.describe Employees::RegisterSalaryChange, type: :model do
  let(:employee) { create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 1)) }

  def call(**overrides)
    described_class.new(
      employee: employee,
      salary_cents: 350_000,
      effective_on: Date.current,
      change_type: "adjustment",
      **overrides
    ).call
  end

  it "creates a salary_changes record" do
    expect { call }.to change { employee.salary_changes.count }.by(1)
  end

  it "records the previous salary based on what is vigente at the new effective_on" do
    change = call(effective_on: Date.current)

    expect(change.previous_salary_cents).to eq(300_000)
    expect(change.salary_cents).to eq(350_000)
  end

  it "updates employees.salary_cents immediately when the change is already effective" do
    call(effective_on: Date.current)

    expect(employee.reload.salary_cents).to eq(350_000)
  end

  it "updates employees.salary_cents for a change effective in the past" do
    call(effective_on: 1.year.ago.to_date)

    expect(employee.reload.salary_cents).to eq(350_000)
  end

  it "does not touch employees.salary_cents for a change effective in the future" do
    call(effective_on: 30.days.from_now.to_date)

    expect(employee.reload.salary_cents).to eq(300_000)
  end

  it "preserves the current salary when a future change is later superseded by another future change" do
    call(effective_on: 60.days.from_now.to_date, salary_cents: 400_000)
    call(effective_on: 30.days.from_now.to_date, salary_cents: 350_000)

    # both changes are still in the future -- current salary stays untouched
    expect(employee.reload.salary_cents).to eq(300_000)
  end

  it "recomputes the current salary correctly when a past-dated correction is inserted after a later change already exists" do
    call(effective_on: 10.days.ago.to_date, salary_cents: 320_000)
    # this correction is inserted for an earlier date than the one above
    change = call(effective_on: 20.days.ago.to_date, salary_cents: 310_000, change_type: "correction")

    expect(change.previous_salary_cents).to eq(300_000) # the initial salary, still the latest before 20 days ago
    # the most recent vigente salary as of today is still the 10-days-ago entry (320_000)
    expect(employee.reload.salary_cents).to eq(320_000)
  end

  it "sets previous_salary_cents to nil only for an employee's very first history entry" do
    fresh_employee = create(:employee, salary_cents: 200_000, started_on: Date.current)
    fresh_employee.salary_changes.destroy_all # simulate an employee with no history at all

    change = described_class.new(
      employee: fresh_employee, salary_cents: 220_000, effective_on: Date.current, change_type: "adjustment"
    ).call

    expect(change.previous_salary_cents).to be_nil
  end

  it "runs inside a transaction: an invalid change rolls back without partial writes" do
    expect do
      described_class.new(
        employee: employee, salary_cents: 350_000, effective_on: nil, change_type: "adjustment"
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(employee.salary_changes.count).to eq(1) # only the initial record, nothing added
    expect(employee.reload.salary_cents).to eq(300_000)
  end
end
