require "rails_helper"

RSpec.describe Employees::TerminationSettlement do
  describe "#call" do
    it "prorates the salary balance by days worked in the termination month" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 20)).call

      expect(result.days_in_month).to eq(31)
      expect(result.days_worked_in_month).to eq(20)
      expect(result.balance_salary_cents).to eq((300_000 * 20 / 31.0).round)
    end

    it "counts a full avo for each complete month and rounds up when 15+ days remain" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 20)).call

      # Jan 1 -> Aug 20: 7 whole months (Jan-Jul) + 19 remaining days (>= 15) = 8 avos
      expect(result.thirteenth_months).to eq(8)
      expect(result.thirteenth_cents).to eq(((300_000 / 12.0) * 8).round)
    end

    it "does not round up the 13º avos when the remaining fraction is under 15 days" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 10)).call

      # Jan 1 -> Aug 10: 7 whole months (Jan-Jul) + 9 remaining days (< 15) = 7 avos
      expect(result.thirteenth_months).to eq(7)
    end

    it "computes proportional vacation + 1/3 from the current open accrual period" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))
      create(
        :employee_vacation,
        employee: employee,
        status: "accruing",
        accrual_started_on: Date.new(2026, 1, 10),
        accrual_ended_on: Date.new(2027, 1, 10)
      )

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 20)).call

      # Jan 10 -> Aug 20: 7 whole months, 10 remaining days (< 15) = 7 avos
      expect(result.vacation_months).to eq(7)
      base = (300_000 / 12.0) * 7
      expect(result.vacation_cents).to eq((base * 4 / 3.0).round)
    end

    it "derives the current accrual period from the admission date when there is no accruing record" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 20)).call

      expect(result.vacation_period_start).to eq(Date.new(2026, 1, 10))
    end

    it "sums the three components into the total" do
      employee = create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10))

      result = described_class.new(employee, reference_date: Date.new(2026, 8, 20)).call

      expect(result.total_cents).to eq(
        result.balance_salary_cents + result.thirteenth_cents + result.vacation_cents
      )
    end

    it "defaults the reference date to the employee's terminated_on" do
      employee = create(
        :employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 10),
        status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      result = described_class.new(employee).call

      expect(result.reference_date).to eq(Date.new(2026, 8, 20))
    end
  end
end
