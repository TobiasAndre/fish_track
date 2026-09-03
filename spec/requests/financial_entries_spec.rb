require "rails_helper"

RSpec.describe "FinancialEntries", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /financial_entries" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get financial_entries_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists entries and computes totals" do
      create(:financial_entry, entry_type: "income", amount_cents: 10_000)
      create(:financial_entry, entry_type: "expense", amount_cents: 4_000)

      get financial_entries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("R$ 100,00") # income
      expect(response.body).to include("R$ 40,00")  # expense
      expect(response.body).to include("R$ 60,00")  # balance
    end

    it "filters by entry_type" do
      create(:financial_entry, entry_type: "income", description: "Venda")
      create(:financial_entry, entry_type: "expense", description: "Combustível")

      get financial_entries_path, params: { entry_type: "income" }

      expect(response.body).to include("Venda")
      expect(response.body).not_to include("Combustível")
    end

    it "filters by batch" do
      batch = create(:batch)
      create(:financial_entry, batch: batch, description: "Ração do lote")
      create(:financial_entry, batch: nil, description: "Despesa geral")

      get financial_entries_path, params: { batch_id: batch.id }

      expect(response.body).to include("Ração do lote")
      expect(response.body).not_to include("Despesa geral")
    end

    it "shows 10 entries per page by default" do
      create_list(:financial_entry, 12)

      get financial_entries_path

      expect(response.body.scan("Editar").size).to eq(10)
    end

    it "honours a valid per_page selection" do
      create_list(:financial_entry, 25)

      get financial_entries_path, params: { per_page: 20 }

      expect(response.body.scan("Editar").size).to eq(20)
    end

    it "falls back to the default for an invalid per_page" do
      create_list(:financial_entry, 15)

      get financial_entries_path, params: { per_page: 999 }

      expect(response.body.scan("Editar").size).to eq(10)
    end
  end

  describe "POST /financial_entries" do
    it "creates an entry with valid params" do
      expect do
        post financial_entries_path, params: {
          financial_entry: {
            entry_type: "expense",
            stage: "general",
            occurred_on: Date.current,
            amount_cents: 5_000,
            description: "Compra de ração"
          }
        }
      end.to change(FinancialEntry, :count).by(1)

      expect(response).to redirect_to(financial_entries_path)
    end

    it "does not create an entry with a zero amount" do
      expect do
        post financial_entries_path, params: {
          financial_entry: {
            entry_type: "expense",
            stage: "general",
            occurred_on: Date.current,
            amount_cents: 0,
            description: "Inválido"
          }
        }
      end.not_to change(FinancialEntry, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /financial_entries/:id" do
    it "updates the entry" do
      entry = create(:financial_entry, description: "Old")

      patch financial_entry_path(entry), params: { financial_entry: { description: "New" } }

      expect(response).to redirect_to(financial_entries_path)
      expect(entry.reload.description).to eq("New")
    end
  end

  describe "DELETE /financial_entries/:id" do
    it "removes the entry" do
      entry = create(:financial_entry)

      expect do
        delete financial_entry_path(entry)
      end.to change(FinancialEntry, :count).by(-1)

      expect(response).to redirect_to(financial_entries_path)
    end
  end
end
