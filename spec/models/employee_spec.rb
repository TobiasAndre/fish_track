require "rails_helper"

RSpec.describe Employee, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:employee) }
  end

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

  it "is invalid without a started_on" do
    employee = build(:employee, started_on: nil)

    expect(employee).not_to be_valid
    expect(employee.errors[:started_on]).to be_present
  end

  describe "status" do
    it "defaults to active" do
      expect(Employee.new.status).to eq("active")
    end

    it "accepts active, inactive and terminated" do
      %w[active inactive terminated].each do |status|
        employee = build(:employee, status: status, terminated_on: status == "terminated" ? Date.current : nil)
        expect(employee).to be_valid
      end
    end

    it "rejects any other status value" do
      expect { build(:employee, status: "on_vacation") }.to raise_error(ArgumentError)
    end

    it "requires terminated_on when status is terminated" do
      employee = build(:employee, status: "terminated", terminated_on: nil)

      expect(employee).not_to be_valid
      expect(employee.errors[:terminated_on]).to be_present
    end

    it "does not require terminated_on for other statuses" do
      employee = build(:employee, status: "active", terminated_on: nil)

      expect(employee).to be_valid
    end

    it "is invalid when terminated_on is before started_on" do
      employee = build(:employee,
        started_on: Date.new(2026, 1, 1),
        status: "terminated",
        terminated_on: Date.new(2025, 12, 31))

      expect(employee).not_to be_valid
      expect(employee.errors[:terminated_on]).to be_present
    end
  end

  describe "on create" do
    it "creates an initial salary_changes record matching the starting salary" do
      employee = create(:employee, salary_cents: 400_000, started_on: Date.new(2026, 2, 1))

      expect(employee.salary_changes.count).to eq(1)
      initial = employee.salary_changes.first
      expect(initial.change_type).to eq("initial")
      expect(initial.previous_salary_cents).to be_nil
      expect(initial.salary_cents).to eq(400_000)
      expect(initial.effective_on).to eq(Date.new(2026, 2, 1))
    end
  end

  describe "#employment_duration_in_months" do
    it "is 0 for an employee hired within the current reference month" do
      employee = build(:employee, started_on: Date.new(2026, 8, 1))

      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 8, 20))).to eq(0)
    end

    it "counts whole months only, not partial ones" do
      employee = build(:employee, started_on: Date.new(2026, 1, 15))

      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 9, 10))).to eq(7)
      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 9, 15))).to eq(8)
    end

    it "counts multiple full years correctly" do
      employee = build(:employee, started_on: Date.new(2024, 5, 1))

      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 8, 1))).to eq(27)
    end

    it "returns 0 for a start date in the future relative to the reference date" do
      employee = build(:employee, started_on: Date.new(2027, 1, 1))

      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 8, 4))).to eq(0)
    end

    it "uses terminated_on as the effective end date once the employee has left" do
      employee = build(:employee,
        started_on: Date.new(2024, 1, 1),
        status: "terminated",
        terminated_on: Date.new(2024, 7, 1))

      # querying long after termination should still be capped at terminated_on
      expect(employee.employment_duration_in_months(reference_date: Date.new(2026, 8, 4))).to eq(6)
    end
  end

  describe "#employment_duration_label" do
    it "shows less than a month for a brand new hire" do
      employee = build(:employee, started_on: Date.new(2026, 8, 1))

      expect(employee.employment_duration_label(reference_date: Date.new(2026, 8, 4))).to eq("menos de 1 mês")
    end

    it "uses singular for exactly one month" do
      employee = build(:employee, started_on: Date.new(2026, 6, 1))

      expect(employee.employment_duration_label(reference_date: Date.new(2026, 7, 2))).to eq("1 mês")
    end

    it "uses plural for multiple months under a year" do
      employee = build(:employee, started_on: Date.new(2026, 1, 1))

      expect(employee.employment_duration_label(reference_date: Date.new(2026, 9, 1))).to eq("8 meses")
    end

    it "uses singular for exactly one year" do
      employee = build(:employee, started_on: Date.new(2025, 8, 1))

      expect(employee.employment_duration_label(reference_date: Date.new(2026, 8, 1))).to eq("1 ano")
    end

    it "combines years and months, pluralized" do
      employee = build(:employee, started_on: Date.new(2024, 5, 1))

      expect(employee.employment_duration_label(reference_date: Date.new(2026, 8, 1))).to eq("2 anos e 3 meses")
    end
  end

  describe "#salary_on" do
    it "falls back to the current salary_cents when no history matches the date" do
      # an unpersisted employee has no persisted salary_changes to match against
      employee = build(:employee, salary_cents: 250_000)

      expect(employee.salary_on(Date.current)).to eq(250_000)
    end

    it "returns the salary in effect on the given date" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 1))
      create(:employee_salary_change,
        employee: employee, salary_cents: 350_000, effective_on: Date.new(2025, 1, 1), change_type: "adjustment")

      expect(employee.salary_on(Date.new(2024, 6, 1))).to eq(300_000)
      expect(employee.salary_on(Date.new(2025, 6, 1))).to eq(350_000)
    end
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
