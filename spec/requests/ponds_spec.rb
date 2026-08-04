require "rails_helper"

RSpec.describe "Ponds", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }

  before { sign_in user }

  describe "GET /ponds" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get ponds_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists ponds" do
      pond = create(:pond, unit: unit, name: "Tanque Norte")

      get ponds_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tanque Norte")
    end
  end

  describe "POST /ponds" do
    it "creates a pond, normalizing a dotted capacity value" do
      post ponds_path, params: {
        pond: { unit_id: unit.id, name: "Tanque A", capacity: "1.500", capacity_unit: "m3" }
      }

      expect(response).to redirect_to(ponds_path)
      expect(Pond.last.capacity).to eq(1500)
    end

    it "does not create a pond without a unit" do
      expect do
        post ponds_path, params: { pond: { unit_id: nil, name: "Tanque A" } }
      end.not_to change(Pond, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /ponds/:id" do
    it "updates the pond" do
      pond = create(:pond, unit: unit, name: "Old name")

      patch pond_path(pond), params: { pond: { name: "New name" } }

      expect(response).to redirect_to(ponds_path)
      expect(pond.reload.name).to eq("New name")
    end
  end

  describe "DELETE /ponds/:id" do
    it "removes the pond" do
      pond = create(:pond, unit: unit)

      expect do
        delete pond_path(pond)
      end.to change(Pond, :count).by(-1)

      expect(response).to redirect_to(ponds_path)
    end
  end
end
