require "rails_helper"

RSpec.describe "EmployeeVacations", type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  describe "POST /employees/:employee_id/vacations" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      post employee_vacations_path(employee), params: {
        employee_vacation: { accrual_started_on: 1.year.ago.to_date, accrual_ended_on: Date.current }
      }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "creates a vacation period" do
      expect do
        post employee_vacations_path(employee), params: {
          employee_vacation: {
            accrual_started_on: 1.year.ago.to_date, accrual_ended_on: Date.current,
            status: "accruing", entitled_days: 30
          }
        }
      end.to change { employee.vacations.count }.by(1)

      expect(response).to redirect_to(employee_path(employee))
    end

    it "redirects back with an alert when the accrual period is invalid" do
      expect do
        post employee_vacations_path(employee), params: {
          employee_vacation: { accrual_started_on: Date.current, accrual_ended_on: 1.year.ago.to_date }
        }
      end.not_to change { employee.vacations.count }

      expect(response).to redirect_to(employee_path(employee))
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /employees/:employee_id/vacations/:id" do
    it "updates the vacation, e.g. moving it to available" do
      vacation = create(:employee_vacation, employee: employee, status: "accruing")

      patch employee_vacation_path(employee, vacation), params: { employee_vacation: { status: "available" } }

      expect(response).to redirect_to(employee_path(employee))
      expect(vacation.reload.status).to eq("available")
    end

    it "schedules a vacation with a scheduled period" do
      vacation = create(:employee_vacation, employee: employee, status: "available")

      patch employee_vacation_path(employee, vacation), params: {
        employee_vacation: {
          status: "scheduled",
          scheduled_start_on: 10.days.from_now.to_date,
          scheduled_end_on: 40.days.from_now.to_date
        }
      }

      vacation.reload
      expect(vacation.status).to eq("scheduled")
      expect(vacation.scheduled_start_on).to eq(10.days.from_now.to_date)
    end

    it "records a payment as made" do
      vacation = create(:employee_vacation, employee: employee, status: "taken",
        payment_due_on: Date.current, payment_amount_cents: 150_000)

      patch employee_vacation_path(employee, vacation), params: {
        employee_vacation: { paid_on: Date.current }
      }

      expect(vacation.reload.paid_on).to eq(Date.current)
    end

    it "redirects back with an alert on an invalid update" do
      vacation = create(:employee_vacation, employee: employee)

      patch employee_vacation_path(employee, vacation), params: {
        employee_vacation: { taken_days: 999 }
      }

      expect(response).to redirect_to(employee_path(employee))
      expect(flash[:alert]).to be_present
    end
  end
end
