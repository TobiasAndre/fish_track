require "rails_helper"

RSpec.describe "FeedingTypes", type: :request do
  let(:user) { create(:user) }
  let(:feeding_brand) { create(:feeding_brand, name: "Guabi") }

  before { sign_in user }

  describe "GET /feeding_types" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_types_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists feeding types with their brand" do
      feeding_type = create(:feeding_type, feeding_brand: feeding_brand)

      get feeding_types_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(feeding_type.name)
      expect(response.body).to include(feeding_brand.name)
    end
  end

  describe "GET /feeding_types/new" do
    it "prompts to create a brand first when none exist" do
      get new_feeding_type_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_feeding_brand_path)
    end
  end

  describe "POST /feeding_types" do
    it "creates a feeding type with a valid name and brand" do
      expect do
        post feeding_types_path, params: { feeding_type: { name: "Extrusada 32%", feeding_brand_id: feeding_brand.id } }
      end.to change(FeedingType, :count).by(1)

      expect(response).to redirect_to(feeding_types_path)
    end

    it "does not create a feeding type without a name" do
      expect do
        post feeding_types_path, params: { feeding_type: { name: "", feeding_brand_id: feeding_brand.id } }
      end.not_to change(FeedingType, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a feeding type without a brand" do
      expect do
        post feeding_types_path, params: { feeding_type: { name: "Extrusada 32%" } }
      end.not_to change(FeedingType, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a trivial duplicate within the same brand (case/whitespace insensitive)" do
      create(:feeding_type, feeding_brand: feeding_brand, name: "Extrusada 32%")

      expect do
        post feeding_types_path, params: { feeding_type: { name: "  extrusada 32%  ", feeding_brand_id: feeding_brand.id } }
      end.not_to change(FeedingType, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "allows the same type name under a different brand" do
      create(:feeding_type, feeding_brand: feeding_brand, name: "Extrusada 32%")
      other_brand = create(:feeding_brand, name: "Purina")

      expect do
        post feeding_types_path, params: { feeding_type: { name: "Extrusada 32%", feeding_brand_id: other_brand.id } }
      end.to change(FeedingType, :count).by(1)

      expect(response).to redirect_to(feeding_types_path)
    end
  end

  describe "PATCH /feeding_types/:id" do
    it "updates the feeding type" do
      feeding_type = create(:feeding_type, feeding_brand: feeding_brand, name: "Old name")

      patch feeding_type_path(feeding_type), params: { feeding_type: { name: "New name" } }

      expect(response).to redirect_to(feeding_types_path)
      expect(feeding_type.reload.name).to eq("New name")
    end
  end

  describe "DELETE /feeding_types/:id" do
    it "removes the feeding type" do
      feeding_type = create(:feeding_type, feeding_brand: feeding_brand)

      expect do
        delete feeding_type_path(feeding_type)
      end.to change(FeedingType, :count).by(-1)

      expect(response).to redirect_to(feeding_types_path)
    end

    it "does not remove a feeding type still used by a feeding entry" do
      feeding_type = create(:feeding_type, feeding_brand: feeding_brand)
      create(:stocking_event, :feeding, feeding_type: feeding_type)

      expect do
        delete feeding_type_path(feeding_type)
      end.not_to change(FeedingType, :count)

      expect(response).to redirect_to(feeding_types_path)
    end
  end
end
