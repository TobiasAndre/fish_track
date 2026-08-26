require "rails_helper"

RSpec.describe "Silos", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }

  before { sign_in user }

  describe "GET /silos" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get silos_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists silos with their unit" do
      silo = create(:silo, unit: unit, name: "Silo Norte")

      get silos_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Silo Norte")
      expect(response.body).to include(unit.name)
    end
  end

  describe "POST /silos" do
    it "creates a silo for a unit" do
      expect do
        post silos_path, params: { silo: { unit_id: unit.id, name: "Silo A" } }
      end.to change(Silo, :count).by(1)

      expect(response).to redirect_to(silos_path)
    end

    it "does not create a silo without a unit" do
      expect do
        post silos_path, params: { silo: { unit_id: nil, name: "Silo A" } }
      end.not_to change(Silo, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a silo without a name" do
      expect do
        post silos_path, params: { silo: { unit_id: unit.id, name: "" } }
      end.not_to change(Silo, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a trivial duplicate within the same unit (case/whitespace insensitive)" do
      create(:silo, unit: unit, name: "Silo A")

      expect do
        post silos_path, params: { silo: { unit_id: unit.id, name: "  silo a  " } }
      end.not_to change(Silo, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "allows the same silo name under a different unit" do
      create(:silo, unit: unit, name: "Silo A")
      other_unit = create(:unit)

      expect do
        post silos_path, params: { silo: { unit_id: other_unit.id, name: "Silo A" } }
      end.to change(Silo, :count).by(1)

      expect(response).to redirect_to(silos_path)
    end
  end

  describe "PATCH /silos/:id" do
    it "updates the silo" do
      silo = create(:silo, unit: unit, name: "Old name")

      patch silo_path(silo), params: { silo: { name: "New name" } }

      expect(response).to redirect_to(silos_path)
      expect(silo.reload.name).to eq("New name")
    end
  end

  describe "DELETE /silos/:id" do
    it "removes the silo" do
      silo = create(:silo, unit: unit)

      expect do
        delete silo_path(silo)
      end.to change(Silo, :count).by(-1)

      expect(response).to redirect_to(silos_path)
    end
  end
end
