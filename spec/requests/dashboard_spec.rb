require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET / (dashboard#show)" do
    it "redirects to sign in when not authenticated" do
      get root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to company selection when authenticated but no tenant/company is selected" do
      sign_in user

      get root_path

      expect(response).to redirect_to(select_company_path)
      expect(flash[:alert]).to eq("Selecione uma empresa para continuar.")
    end
  end
end
