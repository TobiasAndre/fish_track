require "rails_helper"

RSpec.describe "Customers", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /customers" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get customers_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists customers" do
      customer = create(:customer)

      get customers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.name)
    end
  end

  describe "POST /customers" do
    it "creates a customer with valid params" do
      expect do
        post customers_path, params: { customer: { name: "Cliente A" } }
      end.to change(Customer, :count).by(1)

      expect(response).to redirect_to(customers_path)
    end

    it "does not create a customer without a name" do
      expect do
        post customers_path, params: { customer: { name: "" } }
      end.not_to change(Customer, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /customers/:id" do
    it "updates the customer" do
      customer = create(:customer, name: "Old name")

      patch customer_path(customer), params: { customer: { name: "New name" } }

      expect(response).to redirect_to(customers_path)
      expect(customer.reload.name).to eq("New name")
    end
  end

  describe "DELETE /customers/:id" do
    it "removes the customer" do
      customer = create(:customer)

      expect do
        delete customer_path(customer)
      end.to change(Customer, :count).by(-1)

      expect(response).to redirect_to(customers_path)
    end
  end
end
