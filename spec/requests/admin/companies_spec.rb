require "rails_helper"

RSpec.describe "Admin::Companies", type: :request do
  let(:admin) { create(:user, email: "admin@fishtrack.com") }
  let(:regular_user) { create(:user) }

  describe "GET /admin/companies" do
    it "redirects to sign in when not authenticated" do
      get admin_companies_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "denies access to a non-system-admin user" do
      sign_in regular_user

      get admin_companies_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Você não tem permissão para acessar esta área.")
    end

    it "lists companies for the system admin" do
      sign_in admin
      company = create(:company, name: "Empresa Teste")

      get admin_companies_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Empresa Teste")
    end
  end

  describe "GET /admin/companies/new" do
    it "renders the new company form" do
      sign_in admin

      get new_admin_company_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/companies" do
    it "does not create a company without a name (fails before touching Apartment)" do
      sign_in admin

      expect do
        post admin_companies_path, params: { company: { name: "", tenant_name: "acme" } }
      end.not_to change(Company, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /admin/companies/:id" do
    it "updates the company" do
      sign_in admin
      company = create(:company, name: "Old name")

      patch admin_company_path(company), params: { company: { name: "New name" } }

      expect(response).to redirect_to(admin_companies_path)
      expect(company.reload.name).to eq("New name")
    end
  end
end
