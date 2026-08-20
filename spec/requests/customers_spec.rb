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

    it "sorts by name ascending by default" do
      z = create(:customer, name: "Zulu")
      a = create(:customer, name: "Alfa")

      get customers_path

      expect(response.body.index(a.name)).to be < response.body.index(z.name)
    end

    it "sorts by the given column and direction" do
      b = create(:customer, name: "Cliente B", email: "bravo@example.com")
      a = create(:customer, name: "Cliente A", email: "alfa@example.com")

      get customers_path, params: { sort: "email", direction: "desc" }

      expect(response.body.index(b.name)).to be < response.body.index(a.name)
    end

    it "ignores an unknown sort column instead of raising" do
      create(:customer, name: "Qualquer")

      get customers_path, params: { sort: "not_a_real_column" }

      expect(response).to have_http_status(:ok)
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
