require "rails_helper"

RSpec.describe "Integrateds", type: :request do
  let(:user) { create(:user) }
  let(:customer) { create(:customer) }

  before { sign_in user }

  describe "GET /customers/:customer_id/integrateds" do
    it "lists integrateds for the customer" do
      integrated = create(:integrated, customer: customer, name: "Integrado A")

      get customer_integrateds_path(customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Integrado A")
    end
  end

  describe "POST /customers/:customer_id/integrateds" do
    it "creates an integrated scoped to the customer" do
      expect do
        post customer_integrateds_path(customer), params: { integrated: { name: "Integrado B" } }
      end.to change(customer.integrateds, :count).by(1)

      expect(response).to redirect_to(customer_integrateds_path(customer))
    end

    it "does not create an integrated without a name" do
      expect do
        post customer_integrateds_path(customer), params: { integrated: { name: "" } }
      end.not_to change(Integrated, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /customers/:customer_id/integrateds/:id" do
    it "updates the integrated" do
      integrated = create(:integrated, customer: customer, name: "Old name")

      patch customer_integrated_path(customer, integrated), params: { integrated: { name: "New name" } }

      expect(response).to redirect_to(customer_integrateds_path(customer))
      expect(integrated.reload.name).to eq("New name")
    end
  end

  describe "DELETE /customers/:customer_id/integrateds/:id" do
    it "removes the integrated" do
      integrated = create(:integrated, customer: customer)

      expect do
        delete customer_integrated_path(customer, integrated)
      end.to change(Integrated, :count).by(-1)

      expect(response).to redirect_to(customer_integrateds_path(customer))
    end
  end
end
