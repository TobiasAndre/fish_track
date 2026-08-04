require "rails_helper"

RSpec.describe "Employees", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /employees" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get employees_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists employees with their starting date" do
      employee = create(:employee, started_on: Date.new(2026, 3, 10))

      get employees_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.name)
      expect(response.body).to include(I18n.l(Date.new(2026, 3, 10)))
    end

    it "filters by name" do
      match = create(:employee, name: "Maria Souza")
      other = create(:employee, name: "João Lima")

      get employees_path, params: { q: "Maria" }

      expect(response.body).to include(match.name)
      expect(response.body).not_to include(other.name)
    end

    it "filters by status" do
      active = create(:employee, name: "Ativa", status: "active")
      inactive = create(:employee, name: "Inativa", status: "inactive")

      get employees_path, params: { status: "inactive" }

      expect(response.body).to include(inactive.name)
      expect(response.body).not_to include(active.name)
    end

    it "filters by department" do
      sales = create(:employee, name: "Fulano Vendas", department: "Vendas")
      ops = create(:employee, name: "Ciclano Operações", department: "Operações")

      get employees_path, params: { department: "Vendas" }

      expect(response.body).to include(sales.name)
      expect(response.body).not_to include(ops.name)
    end
  end

  describe "GET /employees/:id" do
    it "shows the employee's summary, tenure, salary history and vacations" do
      employee = create(:employee, name: "Perfil Teste", started_on: Date.new(2024, 1, 1), salary_cents: 300_000)

      get employee_path(employee)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Perfil Teste")
      expect(response.body).to include(employee.employment_duration_label)
      expect(response.body).to include("Histórico salarial")
      expect(response.body).to include("Férias")
    end
  end

  describe "POST /employees" do
    it "creates an employee with valid params" do
      expect do
        post employees_path, params: {
          employee: { name: "Funcionário A", role: "Operador", salary_cents: 300_000, started_on: Date.new(2026, 1, 15) }
        }
      end.to change(Employee, :count).by(1)

      expect(response).to redirect_to(employees_path)
      expect(Employee.last.started_on).to eq(Date.new(2026, 1, 15))
    end

    it "does not create an employee without a name" do
      expect do
        post employees_path, params: { employee: { name: "", salary_cents: 300_000, started_on: Date.current } }
      end.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create an employee without a started_on" do
      expect do
        post employees_path, params: { employee: { name: "Funcionário B", salary_cents: 300_000, started_on: "" } }
      end.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a terminated employee without a terminated_on" do
      expect do
        post employees_path, params: {
          employee: { name: "Funcionário C", salary_cents: 300_000, started_on: Date.current, status: "terminated" }
        }
      end.not_to change(Employee, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /employees/:id" do
    it "updates the employee" do
      employee = create(:employee, name: "Old name")

      patch employee_path(employee), params: { employee: { name: "New name" } }

      expect(response).to redirect_to(employees_path)
      expect(employee.reload.name).to eq("New name")
    end

    it "ignores salary_cents -- current salary can only change through a tracked salary change" do
      employee = create(:employee, salary_cents: 300_000)

      patch employee_path(employee), params: { employee: { salary_cents: 999_999 } }

      expect(response).to redirect_to(employees_path)
      expect(employee.reload.salary_cents).to eq(300_000)
    end
  end

  describe "DELETE /employees/:id" do
    it "removes the employee" do
      employee = create(:employee)

      expect do
        delete employee_path(employee)
      end.to change(Employee, :count).by(-1)

      expect(response).to redirect_to(employees_path)
    end
  end
end
