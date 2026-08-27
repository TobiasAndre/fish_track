require "rails_helper"

RSpec.describe EmployeeVacation, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:employee_vacation) }
  end

  it "is valid with an accrual period and a default status" do
    expect(build(:employee_vacation)).to be_valid
  end

  it "defaults status to accruing and entitled_days to 30" do
    vacation = EmployeeVacation.new
    expect(vacation.status).to eq("accruing")
    expect(vacation.entitled_days).to eq(30)
    expect(vacation.taken_days).to eq(0)
  end

  it "is invalid without an accrual_started_on" do
    vacation = build(:employee_vacation, accrual_started_on: nil)

    expect(vacation).not_to be_valid
    expect(vacation.errors[:accrual_started_on]).to be_present
  end

  it "is invalid when the accrual period ends before it starts" do
    vacation = build(:employee_vacation, accrual_started_on: Date.new(2026, 6, 1), accrual_ended_on: Date.new(2026, 1, 1))

    expect(vacation).not_to be_valid
    expect(vacation.errors[:accrual_ended_on]).to be_present
  end

  it "is invalid with a status outside the allowed list" do
    vacation = build(:employee_vacation, status: "bogus")

    expect(vacation).not_to be_valid
    expect(vacation.errors[:status]).to be_present
  end

  it "is invalid with a negative entitled_days" do
    vacation = build(:employee_vacation, entitled_days: -1)

    expect(vacation).not_to be_valid
    expect(vacation.errors[:entitled_days]).to be_present
  end

  it "is invalid when taken_days exceeds entitled_days" do
    vacation = build(:employee_vacation, entitled_days: 20, taken_days: 21)

    expect(vacation).not_to be_valid
    expect(vacation.errors[:taken_days]).to be_present
  end

  it "is valid when taken_days equals entitled_days" do
    vacation = build(:employee_vacation, entitled_days: 20, taken_days: 20)

    expect(vacation).to be_valid
  end

  describe "scheduled period" do
    it "is invalid with only one of the two scheduled dates" do
      vacation = build(:employee_vacation, scheduled_start_on: Date.current, scheduled_end_on: nil)

      expect(vacation).not_to be_valid
      expect(vacation.errors[:base]).to be_present
    end

    it "is invalid when the scheduled period ends before it starts" do
      vacation = build(:employee_vacation,
        scheduled_start_on: Date.new(2026, 6, 10), scheduled_end_on: Date.new(2026, 6, 1))

      expect(vacation).not_to be_valid
      expect(vacation.errors[:scheduled_end_on]).to be_present
    end

    it "is valid with a proper scheduled period" do
      vacation = build(:employee_vacation, status: "scheduled",
        scheduled_start_on: Date.new(2026, 6, 1), scheduled_end_on: Date.new(2026, 6, 30))

      expect(vacation).to be_valid
    end
  end

  describe "taken period" do
    it "is invalid with only one of the two taken dates" do
      vacation = build(:employee_vacation, taken_start_on: Date.current, taken_end_on: nil)

      expect(vacation).not_to be_valid
      expect(vacation.errors[:base]).to be_present
    end

    it "is invalid when the taken period ends before it starts" do
      vacation = build(:employee_vacation,
        taken_start_on: Date.new(2026, 6, 10), taken_end_on: Date.new(2026, 6, 1))

      expect(vacation).not_to be_valid
      expect(vacation.errors[:taken_end_on]).to be_present
    end

    it "is valid with a proper taken period" do
      vacation = build(:employee_vacation, status: "taken", taken_days: 30,
        taken_start_on: Date.new(2026, 6, 1), taken_end_on: Date.new(2026, 6, 30))

      expect(vacation).to be_valid
    end
  end

  describe "status progression" do
    it "allows moving from accruing to available" do
      vacation = create(:employee_vacation, status: "accruing")

      vacation.status = "available"

      expect(vacation).to be_valid
    end

    it "allows moving from available to scheduled with a scheduled period" do
      vacation = create(:employee_vacation, status: "available")

      vacation.assign_attributes(status: "scheduled", scheduled_start_on: Date.current, scheduled_end_on: 30.days.from_now.to_date)

      expect(vacation).to be_valid
    end

    it "allows moving from scheduled to taken with a taken period" do
      vacation = create(:employee_vacation, status: "scheduled",
        scheduled_start_on: Date.current, scheduled_end_on: 30.days.from_now.to_date)

      vacation.assign_attributes(
        status: "taken",
        taken_start_on: Date.current,
        taken_end_on: 30.days.from_now.to_date,
        taken_days: 30
      )

      expect(vacation).to be_valid
    end
  end
end
