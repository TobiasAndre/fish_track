require "rails_helper"

RSpec.describe "Admin::ActivityLogs", type: :request do
  let(:admin) { create(:user, email: "admin@fishtrack.com") }
  let(:regular_user) { create(:user) }

  def log_for(user:, action: "create", resource_type: "Pond", description: "Tanque X", event_type: nil)
    ActivityLog.record!(
      user: user, action: action, resource_type: resource_type,
      description: description, event_type: event_type, company: nil
    )
  end

  describe "GET /admin/activity_logs" do
    it "redirects to sign in when not authenticated" do
      get admin_activity_logs_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "denies access to a non-system-admin user" do
      sign_in regular_user

      get admin_activity_logs_path

      expect(response).to redirect_to(root_path)
    end

    it "lists activity logs for the system admin" do
      log_for(user: admin, description: "Criou o tanque Norte")
      sign_in admin

      get admin_activity_logs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Criou o tanque Norte")
    end

    it "filters by user_id" do
      mine = log_for(user: admin, description: "Log do admin")
      theirs = log_for(user: regular_user, description: "Log de outro")
      sign_in admin

      get admin_activity_logs_path, params: { user_id: admin.id }

      expect(response.body).to include(mine.description)
      expect(response.body).not_to include(theirs.description)
    end

    it "filters by action via the action_type param" do
      created = log_for(user: admin, action: "create", description: "Entrada criada")
      destroyed = log_for(user: admin, action: "destroy", description: "Entrada removida")
      sign_in admin

      get admin_activity_logs_path, params: { action_type: "destroy" }

      expect(response.body).to include(destroyed.description)
      expect(response.body).not_to include(created.description)
    end
  end
end
