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

  describe "GET /payroll alerts" do
    it "shows the alert details in a tooltip and links to the employee page" do
      employee = create(:employee, name: "Com Alerta", started_on: Date.new(2020, 3, 15))
      create(:employee_vacation, employee: employee, status: "available")

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("alerta(s)")
      expect(response.body).to include(employee_path(employee))
      expect(response.body).to include("Férias disponíveis")
    end
  end

  describe "GET /payroll with bonuses" do
    it "adds bonus amounts on top of the salary in the balance to pay" do
      employee = create(:employee, name: "Com Bônus", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "bonus",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  3.500,00")
    end

    it "subtracts advances after adding bonuses" do
      employee = create(:employee, name: "Bônus E Adiantamento", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "bonus",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )
      create(
        :payroll_item, employee: employee, item_type: "advance",
        year: Date.current.year, month: Date.current.month, amount_cents: 100_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  2.500,00")
    end
  end

  describe "GET /payroll with discounts" do
    it "subtracts discount amounts from the balance to pay" do
      employee = create(:employee, name: "Com Desconto", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "discount",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  2.500,00")
    end
  end

  describe "GET /payroll for a terminated employee" do
    it "shows the acerto rescisório card for the competência of the termination" do
      employee = create(
        :employee, name: "Desligado", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 8 }

      expect(response.body).to include("Acerto rescisório")
      expect(response.body).to include("Saldo de salário")
      expect(response.body).to include("13º salário proporcional")
      expect(response.body).to include(termination_report_employee_path(employee))
    end

    it "does not show the card on competências other than the termination month" do
      create(
        :employee, name: "Desligado Antes", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 9 }

      expect(response.body).not_to include("Acerto rescisório")
    end

    it "hides the employee entirely on competências after the termination month" do
      create(
        :employee, name: "Fulano Desligado", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 9 }

      expect(response.body).not_to include("Fulano Desligado")
    end

    it "still lists the employee on competências before the termination" do
      create(
        :employee, name: "Fulano Ativo Antes", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 7 }

      expect(response.body).to include("Fulano Ativo Antes")
    end

    it "creates a payroll item when the lançar button is submitted" do
      employee = create(
        :employee, salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id, year: 2026, month: 8, item_type: "bonus",
            occurred_on: employee.terminated_on, amount_cents: 200_000,
            notes: "13º salário proporcional (acerto rescisório)"
          }
        }
      end.to change(PayrollItem, :count).by(1)

      item = PayrollItem.last
      expect(item.item_type).to eq("bonus")
      expect(item.amount_cents).to eq(200_000)
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
