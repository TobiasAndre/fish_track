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

  describe "GET /payroll uses the salary vigente na competência" do
    it "shows the salary that was in effect during an old competence, not the current one" do
      employee = create(:employee, name: "Histórico Salarial", salary_cents: 300_000, started_on: Date.new(2024, 1, 1))
      Employees::RegisterSalaryChange.new(
        employee: employee, salary_cents: 400_000, effective_on: Date.new(2026, 1, 1), change_type: "adjustment"
      ).call

      get payroll_path, params: { year: 2025, month: 6 } # a competence before the raise

      expect(response.body).to include("R$  3.000,00")
      expect(response.body).not_to include("R$  4.000,00")
    end

    it "does not let the current salary retroactively change an old payroll" do
      employee = create(:employee, name: "Sem Retroatividade", salary_cents: 300_000, started_on: Date.new(2024, 1, 1))

      get payroll_path, params: { year: 2024, month: 6 }
      expect(response.body).to include("R$  3.000,00")

      Employees::RegisterSalaryChange.new(
        employee: employee, salary_cents: 500_000, effective_on: Date.current, change_type: "adjustment"
      ).call

      get payroll_path, params: { year: 2024, month: 6 }
      expect(response.body).to include("R$  3.000,00")
      expect(response.body).not_to include("R$  5.000,00")
    end

    it "shows the current salary for the present competence" do
      employee = create(:employee, name: "Competência Atual", salary_cents: 300_000, started_on: 2.years.ago.to_date)

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  3.000,00")
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
