require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

  describe "POST /users/sign_in" do
    it "rejects sign in without a tenant_name" do
      post user_session_path, params: { user: { tenant_name: "", email: user.email, password: "password123" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to eq("Selecione uma empresa.")
    end

    it "rejects sign in for a tenant_name with no matching company" do
      post user_session_path, params: { user: { tenant_name: "does-not-exist", email: user.email, password: "password123" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to eq("Empresa inválida.")
    end

    it "rejects sign in when the user has no membership in the company" do
      create(:company, tenant_name: "public")

      post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "signs in and stores the tenant_name in session when the membership exists" do
      company = create(:company, tenant_name: "public")
      create(:membership, user: user, company: company, role: "owner")

      post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }

      expect(response).to redirect_to(root_path)

      # session[:tenant_name] is now set, and the user is genuinely signed in:
      # a plain authenticated page no longer bounces to the sign-in form.
      get units_path

      expect(response).to have_http_status(:ok)
    end
  end
end
