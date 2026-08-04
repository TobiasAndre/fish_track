require "rails_helper"

RSpec.describe EmployeeAlerts, type: :model do
  let(:employee) { create(:employee, started_on: Date.new(2024, 8, 20)) }

  describe "contract anniversary" do
    it "alerts when the next anniversary is within 30 days" do
      alerts = described_class.new(employee, reference_date: Date.new(2026, 8, 4)).call

      anniversary = alerts.find { |a| a.type == :contract_anniversary }
      expect(anniversary).to be_present
      expect(anniversary.due_on).to eq(Date.new(2026, 8, 20))
      expect(anniversary.severity).to eq(:info)
    end

    it "does not alert when the next anniversary is outside the 30-day window" do
      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      expect(alerts.map(&:type)).not_to include(:contract_anniversary)
    end

    it "does not alert for a terminated employee" do
      terminated = create(:employee,
        started_on: Date.new(2024, 8, 20), status: "terminated", terminated_on: Date.new(2026, 1, 1))

      alerts = described_class.new(terminated, reference_date: Date.new(2026, 8, 4)).call

      expect(alerts.map(&:type)).not_to include(:contract_anniversary)
    end

    it "does not alert for an employee hired on the reference date itself (0 years is not an anniversary)" do
      new_hire = create(:employee, started_on: Date.new(2026, 8, 4))

      alerts = described_class.new(new_hire, reference_date: Date.new(2026, 8, 4)).call

      expect(alerts.map(&:type)).not_to include(:contract_anniversary)
    end

    it "does not alert for an employee hired within the last year, even close to the calendar date" do
      recent_hire = create(:employee, started_on: Date.new(2026, 7, 20))

      # the 1-year anniversary is still ~11 months away, not the (nonexistent) 0-year mark
      alerts = described_class.new(recent_hire, reference_date: Date.new(2026, 8, 4)).call

      expect(alerts.map(&:type)).not_to include(:contract_anniversary)
    end
  end

  describe "available vacation" do
    it "alerts when the employee has an available vacation period" do
      create(:employee_vacation, employee: employee, status: "available")

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      expect(alerts.map(&:type)).to include(:vacation_available)
    end

    it "does not alert when there is no available period" do
      create(:employee_vacation, employee: employee, status: "accruing")

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      expect(alerts.map(&:type)).not_to include(:vacation_available)
    end
  end

  describe "scheduled vacation" do
    it "alerts when a scheduled period starts within 30 days" do
      create(:employee_vacation,
        employee: employee, status: "scheduled",
        scheduled_start_on: Date.new(2026, 6, 15), scheduled_end_on: Date.new(2026, 7, 15))

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      scheduled = alerts.find { |a| a.type == :vacation_scheduled }
      expect(scheduled).to be_present
      expect(scheduled.due_on).to eq(Date.new(2026, 6, 15))
    end

    it "does not alert when the scheduled period is far in the future" do
      create(:employee_vacation,
        employee: employee, status: "scheduled",
        scheduled_start_on: Date.new(2026, 12, 1), scheduled_end_on: Date.new(2026, 12, 30))

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      expect(alerts.map(&:type)).not_to include(:vacation_scheduled)
    end
  end

  describe "vacation payment" do
    it "alerts as a warning when the payment is due soon but not yet overdue" do
      create(:employee_vacation,
        employee: employee, status: "taken",
        taken_start_on: Date.new(2026, 5, 1), taken_end_on: Date.new(2026, 5, 30), taken_days: 30,
        payment_due_on: Date.new(2026, 6, 10))

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      payment_alert = alerts.find { |a| a.type == :vacation_payment_pending }
      expect(payment_alert).to be_present
      expect(payment_alert.severity).to eq(:warning)
    end

    it "alerts as danger when the payment is overdue" do
      create(:employee_vacation,
        employee: employee, status: "taken",
        taken_start_on: Date.new(2026, 4, 1), taken_end_on: Date.new(2026, 4, 30), taken_days: 30,
        payment_due_on: Date.new(2026, 5, 1))

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      payment_alert = alerts.find { |a| a.type == :vacation_payment_pending }
      expect(payment_alert).to be_present
      expect(payment_alert.severity).to eq(:danger)
    end

    it "does not alert when the payment has already been made" do
      create(:employee_vacation,
        employee: employee, status: "taken",
        taken_start_on: Date.new(2026, 4, 1), taken_end_on: Date.new(2026, 4, 30), taken_days: 30,
        payment_due_on: Date.new(2026, 5, 1), paid_on: Date.new(2026, 4, 28))

      alerts = described_class.new(employee, reference_date: Date.new(2026, 6, 1)).call

      expect(alerts.map(&:type)).not_to include(:vacation_payment_pending)
    end
  end

  it "returns no alerts when nothing is due" do
    alerts = described_class.new(employee, reference_date: Date.new(2026, 3, 1)).call

    expect(alerts).to be_empty
  end
end
