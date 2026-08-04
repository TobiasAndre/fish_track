require "rails_helper"

RSpec.describe "Payroll", type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  describe "GET /payroll" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get payroll_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the payroll for the given month" do
      create(:payroll_item, employee: employee, item_type: "salary", year: 2026, month: 6, amount_cents: 500_000)

      get payroll_path, params: { year: 2026, month: 6 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.name)
    end
  end

  describe "PATCH /payroll" do
    it "creates a salary payroll item for each employee with a positive amount" do
      expect do
        patch payroll_path, params: {
          year: 2026,
          month: 6,
          salaries: { employee.id.to_s => "500000" }
        }
      end.to change { PayrollItem.where(employee: employee, item_type: "salary", year: 2026, month: 6).count }.by(1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(PayrollItem.find_by(employee: employee, item_type: "salary", year: 2026, month: 6).amount_cents).to eq(500_000)
    end

    it "removes the salary item when the amount is zeroed out" do
      create(:payroll_item, employee: employee, item_type: "salary", year: 2026, month: 6, amount_cents: 500_000)

      expect do
        patch payroll_path, params: {
          year: 2026,
          month: 6,
          salaries: { employee.id.to_s => "0" }
        }
      end.to change { PayrollItem.where(employee: employee, item_type: "salary", year: 2026, month: 6).count }.by(-1)
    end
  end
end
