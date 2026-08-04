require "rails_helper"

RSpec.describe "Units", type: :request do
  describe "GET /units" do
    it "redirects to sign in when not authenticated" do
      get units_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists units when authenticated" do
      user = create(:user)
      sign_in user
      unit = create(:unit)

      get units_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unit.name)
    end
  end
end
