require "rails_helper"

RSpec.describe "PaymentTerms", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /payment_terms" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get payment_terms_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists payment terms" do
      payment_term = create(:payment_term)

      get payment_terms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(payment_term.name)
    end
  end

  describe "POST /payment_terms" do
    it "creates a payment term with valid params" do
      expect do
        post payment_terms_path, params: { payment_term: { name: "30 dias", days: 30, active: true } }
      end.to change(PaymentTerm, :count).by(1)

      expect(response).to redirect_to(payment_terms_path)
      expect(PaymentTerm.last.days).to eq(30)
    end

    it "creates a payment term with an installment plan" do
      post payment_terms_path, params: { payment_term: {
        name: "3x 30/60/90", days: 30, installments_count: 3, interval_days: 30, active: true
      } }

      term = PaymentTerm.last
      expect(term.installments_count).to eq(3)
      expect(term.interval_days).to eq(30)
      expect(term.installment_schedule(Date.new(2026, 1, 1), 9_000).size).to eq(3)
    end

    it "creates a payment term with custom due-day offsets" do
      post payment_terms_path, params: { payment_term: {
        name: "Entrada + 2x", day_offsets_list: "0, 30, 60", active: true
      } }

      expect(PaymentTerm.last.day_offsets).to eq([0, 30, 60])
    end

    it "does not create a payment term without a name" do
      expect do
        post payment_terms_path, params: { payment_term: { name: "", active: true } }
      end.not_to change(PaymentTerm, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /payment_terms/:id" do
    it "updates the payment term" do
      payment_term = create(:payment_term, name: "Old name")

      patch payment_term_path(payment_term), params: { payment_term: { name: "New name" } }

      expect(response).to redirect_to(payment_terms_path)
      expect(payment_term.reload.name).to eq("New name")
    end
  end

  describe "DELETE /payment_terms/:id" do
    it "removes the payment term" do
      payment_term = create(:payment_term)

      expect do
        delete payment_term_path(payment_term)
      end.to change(PaymentTerm, :count).by(-1)

      expect(response).to redirect_to(payment_terms_path)
    end
  end
end
