require "rails_helper"

# NOTE: The happy path (editing settings for the currently selected tenant)
# needs a real Apartment tenant schema, which the suite deliberately avoids
# creating. These specs cover authentication and the "no tenant selected"
# guard; deeper coverage would require provisioning a tenant.
RSpec.describe "Admin::CompanySettings", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }

  describe "GET /admin/company_settings/:id/edit" do
    it "redirects to sign in when not authenticated" do
      get edit_admin_company_setting_path(company)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns not found when no tenant is selected in the session" do
      sign_in user

      get edit_admin_company_setting_path(company)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /admin/company_settings/:id" do
    it "redirects to sign in when not authenticated" do
      patch admin_company_setting_path(company), params: { company: { logo_url: "x" } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
