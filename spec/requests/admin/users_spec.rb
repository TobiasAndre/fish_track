require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, email: "admin@fishtrack.com") }

  before { sign_in admin }

  describe "GET /admin/users" do
    it "lists users" do
      user = create(:user, name: "Fulano de Tal")

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fulano de Tal")
    end
  end

  describe "POST /admin/users" do
    it "creates a user with valid params" do
      expect do
        post admin_users_path, params: {
          user: {
            name: "Novo usuário",
            email: "novo@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(admin_users_path)
    end

    it "does not create a user with mismatched password confirmation" do
      expect do
        post admin_users_path, params: {
          user: {
            name: "Novo usuário",
            email: "novo@example.com",
            password: "password123",
            password_confirmation: "different"
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /admin/users/:id" do
    it "updates the user's name without requiring a password" do
      user = create(:user, name: "Old name")

      patch admin_user_path(user), params: { user: { name: "New name", password: "", password_confirmation: "" } }

      expect(response).to redirect_to(admin_users_path)
      expect(user.reload.name).to eq("New name")
    end
  end
end
