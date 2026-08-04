require "rails_helper"

RSpec.describe "Products", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /products" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get products_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists products" do
      product = create(:product)

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(product.name)
    end
  end

  describe "POST /products" do
    it "creates a product with valid params" do
      expect do
        post products_path, params: { product: { name: "Ração 30%", unit: "kg", active: true } }
      end.to change(Product, :count).by(1)

      expect(response).to redirect_to(products_path)
    end

    it "does not create a product with a unit outside the allowed list" do
      expect do
        post products_path, params: { product: { name: "Ração", unit: "toneladas", active: true } }
      end.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /products/:id" do
    it "updates the product" do
      product = create(:product, name: "Old name")

      patch product_path(product), params: { product: { name: "New name" } }

      expect(response).to redirect_to(products_path)
      expect(product.reload.name).to eq("New name")
    end
  end

  describe "DELETE /products/:id" do
    it "removes the product" do
      product = create(:product)

      expect do
        delete product_path(product)
      end.to change(Product, :count).by(-1)

      expect(response).to redirect_to(products_path)
    end
  end
end
