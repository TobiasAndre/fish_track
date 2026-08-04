require "rails_helper"

RSpec.describe EmployeeSalaryChange, type: :model do
  it "is valid with an employee, salary_cents, effective_on and change_type" do
    expect(build(:employee_salary_change)).to be_valid
  end

  it "is invalid without a salary_cents" do
    change = build(:employee_salary_change, salary_cents: nil)

    expect(change).not_to be_valid
    expect(change.errors[:salary_cents]).to be_present
  end

  it "is invalid with a negative salary_cents" do
    change = build(:employee_salary_change, salary_cents: -1)

    expect(change).not_to be_valid
    expect(change.errors[:salary_cents]).to be_present
  end

  it "is invalid without an effective_on" do
    change = build(:employee_salary_change, effective_on: nil)

    expect(change).not_to be_valid
    expect(change.errors[:effective_on]).to be_present
  end

  it "is invalid with a change_type outside the allowed list" do
    change = build(:employee_salary_change, change_type: "bogus")

    expect(change).not_to be_valid
    expect(change.errors[:change_type]).to be_present
  end

  it "accepts every documented change_type" do
    EmployeeSalaryChange::CHANGE_TYPES.each do |change_type|
      expect(build(:employee_salary_change, change_type: change_type)).to be_valid
    end
  end

  it "allows a blank previous_salary_cents (first record in the history)" do
    change = build(:employee_salary_change, previous_salary_cents: nil)

    expect(change).to be_valid
  end

  it "is invalid with a negative previous_salary_cents" do
    change = build(:employee_salary_change, previous_salary_cents: -1)

    expect(change).not_to be_valid
    expect(change.errors[:previous_salary_cents]).to be_present
  end

  it "does not require a created_by" do
    change = build(:employee_salary_change, created_by: nil)

    expect(change).to be_valid
  end

  it "associates a created_by user when given" do
    user = create(:user)
    change = create(:employee_salary_change, created_by: user)

    expect(change.reload.created_by).to eq(user)
  end
end
