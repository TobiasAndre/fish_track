require "rails_helper"

RSpec.describe "FinancialPayments", type: :request do
  let(:user) { create(:user) }
  let(:entry) { create(:financial_entry, entry_type: "income", amount_cents: 100_000, description: "Venda Azul") }

  before { sign_in user }

  describe "GET /financial_entries/:id/payments" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get financial_entry_payments_path(entry)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the entry summary, its payments and a form pre-filled with the balance" do
      entry.payments.create!(paid_on: Date.new(2026, 9, 1), amount_cents: 30_000, notes: "Sinal")

      get financial_entry_payments_path(entry)

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      expect(doc.text).to include("Venda Azul", "Recebimentos", "Sinal", "R$ 1.000,00", "R$ 300,00", "R$ 700,00")
      expect(doc.at_css("#financial_payment_amount_cents")["value"]).to eq("70000")
    end

    it "uses payment wording for expenses" do
      expense = create(:financial_entry, entry_type: "expense")

      get financial_entry_payments_path(expense)

      expect(response.body).to include("Pagamentos")
      expect(response.body).not_to include("Recebimentos")
    end

    it "hides the form when the entry is already settled" do
      entry.settle!

      get financial_entry_payments_path(entry)

      expect(response.body).to include("está liquidado")
      expect(response.body).not_to include('id="financial_payment_amount_cents"')
    end
  end

  describe "POST /financial_entries/:id/payments" do
    it "registers a partial payment, leaving the entry pending with the balance" do
      expect do
        post financial_entry_payments_path(entry), params: {
          financial_payment: { paid_on: Date.current, amount_cents: 25_000, notes: "1ª parcela" }
        }
      end.to change { entry.payments.count }.by(1)

      expect(response).to redirect_to(financial_entry_payments_path(entry))
      entry.reload
      expect(entry).to be_partially_paid
      expect(entry.balance_cents).to eq(75_000)
    end

    it "settles the entry when the payments reach the full amount" do
      post financial_entry_payments_path(entry), params: { financial_payment: { paid_on: Date.current, amount_cents: 40_000 } }
      post financial_entry_payments_path(entry), params: { financial_payment: { paid_on: Date.current, amount_cents: 60_000 } }

      expect(entry.reload).to be_settled
    end

    it "rejects a payment above the balance and shows why" do
      expect do
        post financial_entry_payments_path(entry), params: { financial_payment: { paid_on: Date.current, amount_cents: 100_001 } }
      end.not_to change(FinancialPayment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("excede o saldo")
    end

    it "rejects a future date" do
      expect do
        post financial_entry_payments_path(entry), params: { financial_payment: { paid_on: Date.current.next_day, amount_cents: 1_000 } }
      end.not_to change(FinancialPayment, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /financial_entries/:id/payments/:id" do
    it "removes the payment and reopens the balance" do
      payment = entry.payments.create!(paid_on: Date.current, amount_cents: 100_000)
      expect(entry.reload).to be_settled

      delete financial_entry_payment_path(entry, payment)

      expect(response).to redirect_to(financial_entry_payments_path(entry))
      expect(entry.reload).to be_pending
      expect(entry.paid_cents).to eq(0)
    end

    it "cannot remove a payment that belongs to another entry" do
      other = create(:financial_entry)
      foreign = other.payments.create!(paid_on: Date.current, amount_cents: 1_000)

      delete financial_entry_payment_path(entry, foreign)

      expect(response).to have_http_status(:not_found)
      expect(FinancialPayment.exists?(foreign.id)).to be(true)
    end
  end
end
