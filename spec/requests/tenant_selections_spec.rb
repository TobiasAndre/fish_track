require "rails_helper"

RSpec.describe "TenantSelections", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company, name: "Empresa Alvo", tenant_name: "empresa_alvo") }

  describe "GET /select_company" do
    it "redirects to sign in when not authenticated" do
      get select_company_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists the companies the user belongs to" do
      create(:membership, user: user, company: company)
      sign_in user

      get select_company_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Empresa Alvo")
    end
  end

  describe "POST /select_company" do
    before { sign_in user }

    it "stores the tenant in the session and redirects to root when the user has a membership" do
      create(:membership, user: user, company: company)

      post select_company_path, params: { tenant_name: company.tenant_name }

      expect(response).to redirect_to(root_path)
      expect(session[:tenant_name]).to eq(company.tenant_name)
    end

    it "re-renders with an alert when the user has no membership for the company" do
      company

      post select_company_path, params: { tenant_name: company.tenant_name }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Você não tem acesso a esta empresa.")
      expect(session[:tenant_name]).to be_nil
    end

    it "re-renders with an alert when the company does not exist" do
      post select_company_path, params: { tenant_name: "inexistente" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:tenant_name]).to be_nil
    end
  end
end
