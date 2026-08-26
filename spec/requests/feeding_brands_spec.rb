require "rails_helper"

RSpec.describe "FeedingBrands", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /feeding_brands" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_brands_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists feeding brands" do
      feeding_brand = create(:feeding_brand)

      get feeding_brands_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(feeding_brand.name)
    end
  end

  describe "POST /feeding_brands" do
    it "creates a feeding brand with a valid name" do
      expect do
        post feeding_brands_path, params: { feeding_brand: { name: "Guabi" } }
      end.to change(FeedingBrand, :count).by(1)

      expect(response).to redirect_to(feeding_brands_path)
    end

    it "does not create a feeding brand without a name" do
      expect do
        post feeding_brands_path, params: { feeding_brand: { name: "" } }
      end.not_to change(FeedingBrand, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a trivial duplicate (case/whitespace insensitive)" do
      create(:feeding_brand, name: "Guabi")

      expect do
        post feeding_brands_path, params: { feeding_brand: { name: "  guabi  " } }
      end.not_to change(FeedingBrand, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /feeding_brands/:id" do
    it "updates the feeding brand" do
      feeding_brand = create(:feeding_brand, name: "Old name")

      patch feeding_brand_path(feeding_brand), params: { feeding_brand: { name: "New name" } }

      expect(response).to redirect_to(feeding_brands_path)
      expect(feeding_brand.reload.name).to eq("New name")
    end
  end

  describe "DELETE /feeding_brands/:id" do
    it "removes the feeding brand" do
      feeding_brand = create(:feeding_brand)

      expect do
        delete feeding_brand_path(feeding_brand)
      end.to change(FeedingBrand, :count).by(-1)

      expect(response).to redirect_to(feeding_brands_path)
    end

    it "does not remove a feeding brand still used by a feeding type" do
      feeding_brand = create(:feeding_brand)
      create(:feeding_type, feeding_brand: feeding_brand)

      expect do
        delete feeding_brand_path(feeding_brand)
      end.not_to change(FeedingBrand, :count)

      expect(response).to redirect_to(feeding_brands_path)
    end
  end
end
