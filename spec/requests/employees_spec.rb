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

    it "lists employees" do
      employee = create(:employee)

      get employees_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.name)
    end
  end

  describe "POST /employees" do
    it "creates an employee with valid params" do
      expect do
        post employees_path, params: { employee: { name: "Funcionário A", role: "Operador", salary_cents: 300_000 } }
      end.to change(Employee, :count).by(1)

      expect(response).to redirect_to(employees_path)
    end

    it "does not create an employee without a name" do
      expect do
        post employees_path, params: { employee: { name: "", salary_cents: 300_000 } }
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
