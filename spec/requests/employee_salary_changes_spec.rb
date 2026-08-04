require "rails_helper"

RSpec.describe "EmployeeSalaryChanges", type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, salary_cents: 300_000, started_on: Date.new(2024, 1, 1)) }

  before { sign_in user }

  describe "POST /employees/:employee_id/salary_changes" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      post employee_salary_changes_path(employee), params: {
        employee_salary_change: { salary_cents: 350_000, effective_on: Date.current, change_type: "adjustment" }
      }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "registers a salary change and updates the employee's current salary" do
      expect do
        post employee_salary_changes_path(employee), params: {
          employee_salary_change: {
            salary_cents: 350_000, effective_on: Date.current, change_type: "adjustment", reason: "Reajuste anual"
          }
        }
      end.to change { employee.salary_changes.count }.by(1)

      expect(response).to redirect_to(employee_path(employee))
      expect(employee.reload.salary_cents).to eq(350_000)
    end

    it "records the signed-in user as created_by" do
      post employee_salary_changes_path(employee), params: {
        employee_salary_change: { salary_cents: 350_000, effective_on: Date.current, change_type: "adjustment" }
      }

      expect(employee.salary_changes.recent_first.first.created_by).to eq(user)
    end

    it "does not update the current salary for a future-effective change" do
      post employee_salary_changes_path(employee), params: {
        employee_salary_change: {
          salary_cents: 400_000, effective_on: 30.days.from_now.to_date, change_type: "promotion"
        }
      }

      expect(response).to redirect_to(employee_path(employee))
      expect(employee.reload.salary_cents).to eq(300_000)
    end

    it "redirects back with an alert when the change is invalid" do
      expect do
        post employee_salary_changes_path(employee), params: {
          employee_salary_change: { salary_cents: 350_000, effective_on: nil, change_type: "adjustment" }
        }
      end.not_to change { employee.salary_changes.count }

      expect(response).to redirect_to(employee_path(employee))
      expect(flash[:alert]).to be_present
    end
  end
end
