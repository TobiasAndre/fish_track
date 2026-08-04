require "rails_helper"

RSpec.describe "PaymentMethods", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /payment_methods" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get payment_methods_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists payment methods" do
      payment_method = create(:payment_method)

      get payment_methods_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(payment_method.name)
    end
  end

  describe "POST /payment_methods" do
    it "creates a payment method with valid params" do
      expect do
        post payment_methods_path, params: { payment_method: { name: "Pix", active: true } }
      end.to change(PaymentMethod, :count).by(1)

      expect(response).to redirect_to(payment_methods_path)
    end

    it "does not create a payment method without a name" do
      expect do
        post payment_methods_path, params: { payment_method: { name: "", active: true } }
      end.not_to change(PaymentMethod, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /payment_methods/:id" do
    it "updates the payment method" do
      payment_method = create(:payment_method, name: "Old name")

      patch payment_method_path(payment_method), params: { payment_method: { name: "New name" } }

      expect(response).to redirect_to(payment_methods_path)
      expect(payment_method.reload.name).to eq("New name")
    end
  end

  describe "DELETE /payment_methods/:id" do
    it "removes the payment method" do
      payment_method = create(:payment_method)

      expect do
        delete payment_method_path(payment_method)
      end.to change(PaymentMethod, :count).by(-1)

      expect(response).to redirect_to(payment_methods_path)
    end
  end
end
