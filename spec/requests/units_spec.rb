require "rails_helper"

RSpec.describe "Units", type: :request do
  let(:user) { create(:user) }

  describe "GET /units" do
    it "redirects to sign in when not authenticated" do
      get units_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists units when authenticated" do
      sign_in user
      unit = create(:unit)

      get units_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unit.name)
    end
  end

  describe "GET /units/new" do
    it "renders the form" do
      sign_in user

      get new_unit_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /units" do
    before { sign_in user }

    it "creates a unit with valid params" do
      expect do
        post units_path, params: { unit: { name: "Fazenda Norte" } }
      end.to change(Unit, :count).by(1)

      expect(response).to redirect_to(units_path)
      expect(Unit.last.name).to eq("Fazenda Norte")
    end

    it "re-renders with errors when the name is blank" do
      expect do
        post units_path, params: { unit: { name: "" } }
      end.not_to change(Unit, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /units/:id/edit" do
    it "renders the form" do
      sign_in user
      unit = create(:unit)

      get edit_unit_path(unit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unit.name)
    end
  end

  describe "PATCH /units/:id" do
    before { sign_in user }

    it "updates the unit" do
      unit = create(:unit, name: "Antigo")

      patch unit_path(unit), params: { unit: { name: "Novo" } }

      expect(response).to redirect_to(units_path)
      expect(unit.reload.name).to eq("Novo")
    end

    it "re-renders with errors when the name is blank" do
      unit = create(:unit, name: "Antigo")

      patch unit_path(unit), params: { unit: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(unit.reload.name).to eq("Antigo")
    end
  end

  describe "DELETE /units/:id" do
    it "removes the unit and its dependent ponds" do
      sign_in user
      unit = create(:unit)
      create(:pond, unit: unit)

      expect do
        delete unit_path(unit)
      end.to change(Unit, :count).by(-1).and change(Pond, :count).by(-1)

      expect(response).to redirect_to(units_path)
    end
  end
end
