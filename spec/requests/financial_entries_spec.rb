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

      expect(Nokogiri::HTML(response.body).css("a[title=Editar]").size).to eq(10)
    end

    it "honours a valid per_page selection" do
      create_list(:financial_entry, 25)

      get financial_entries_path, params: { per_page: 20 }

      expect(Nokogiri::HTML(response.body).css("a[title=Editar]").size).to eq(20)
    end

    it "falls back to the default for an invalid per_page" do
      create_list(:financial_entry, 15)

      get financial_entries_path, params: { per_page: 999 }

      expect(Nokogiri::HTML(response.body).css("a[title=Editar]").size).to eq(10)
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

  describe "GET /financial_entries.pdf" do
    it "renders a PDF report" do
      create(:financial_entry, entry_type: "income", amount_cents: 10_000)
      create(:financial_entry, entry_type: "expense", amount_cents: 4_000, settled_on: nil, due_on: Date.current.prev_day)

      get financial_entries_path(format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not paginated (includes every matching entry)" do
      create_list(:financial_entry, 12)

      get financial_entries_path(format: :pdf, per_page: 10)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "filtering by status" do
    it "returns only pending / overdue / settled entries" do
      create(:financial_entry, description: "LancFuturoAberto", due_on: Date.current.next_month, settled_on: nil)
      create(:financial_entry, description: "LancAtrasado", due_on: Date.current.prev_day, settled_on: nil)
      create(:financial_entry, description: "LancLiquidado", settled_on: Date.current)

      get financial_entries_path, params: { status: "pending" }
      expect(response.body).to include("LancFuturoAberto", "LancAtrasado")
      expect(response.body).not_to include("LancLiquidado")

      get financial_entries_path, params: { status: "overdue" }
      expect(response.body).to include("LancAtrasado")
      expect(response.body).not_to include("LancFuturoAberto")

      get financial_entries_path, params: { status: "settled" }
      expect(response.body).to include("LancLiquidado")
      expect(response.body).not_to include("LancAtrasado")
    end
  end

  describe "PATCH /financial_entries/:id/settle" do
    it "marks the entry as settled" do
      entry = create(:financial_entry, settled_on: nil)

      patch settle_financial_entry_path(entry), params: { settled_on: "2026-05-10" }

      expect(response).to redirect_to(financial_entries_path)
      expect(entry.reload.settled_on).to eq(Date.new(2026, 5, 10))
    end

    it "defaults the settlement date to today" do
      entry = create(:financial_entry, settled_on: nil)

      patch settle_financial_entry_path(entry)

      expect(entry.reload.settled_on).to eq(Date.current)
    end
  end

  describe "PATCH /financial_entries/:id/unsettle" do
    it "reopens a settled entry" do
      entry = create(:financial_entry, settled_on: Date.current)

      patch unsettle_financial_entry_path(entry)

      expect(response).to redirect_to(financial_entries_path)
      expect(entry.reload.settled_on).to be_nil
    end
  end

  describe "POST /financial_entries with settlement" do
    it "creates a pending entry when 'já liquidado' is unchecked" do
      post financial_entries_path, params: {
        financial_entry: {
          entry_type: "expense", stage: "general",
          occurred_on: Date.current, due_on: Date.current.next_month,
          amount_cents: 5_000, description: "Conta a pagar", mark_settled: "0"
        }
      }

      expect(FinancialEntry.last).to be_pending
      expect(FinancialEntry.last.due_on).to eq(Date.current.next_month)
    end

    it "creates a settled entry when 'já liquidado' is checked" do
      post financial_entries_path, params: {
        financial_entry: {
          entry_type: "income", stage: "general",
          occurred_on: Date.current, amount_cents: 5_000,
          description: "Recebido à vista", mark_settled: "1"
        }
      }

      expect(FinancialEntry.last).to be_settled
    end
  end

  describe "partial payments" do
    let!(:partial) do
      create(:financial_entry, amount_cents: 100_000, description: "Ração parcial", due_on: Date.current.next_day).tap do |e|
        e.payments.create!(paid_on: Date.current, amount_cents: 30_000)
      end
    end
    let!(:open_entry) { create(:financial_entry, amount_cents: 50_000, description: "Sem pagamento", due_on: Date.current.next_day) }
    let!(:settled) { create(:financial_entry, description: "Quitado").tap(&:settle!) }

    it "filters by the partial status" do
      get financial_entries_path, params: { status: "partial" }

      expect(response.body).to include("Ração parcial")
      expect(response.body).not_to include("Sem pagamento")
      expect(response.body).not_to include("Quitado")
    end

    it "shows the partial badge with the amount already paid and the balance" do
      get financial_entries_path

      row = Nokogiri::HTML(response.body).css("tr").find { |tr| tr.text.include?("Ração parcial") }
      expect(row.text).to include("Parcial", "Pago R$ 300,00", "Saldo R$ 700,00")
    end

    it "counts only the open balance in the pending totals" do
      get financial_entries_path

      # saldo da parcial (R$ 700) + entrada sem pagamento (R$ 500)
      expect(response.body).to include("R$ 1.200,00")
    end

    it "keeps 'Liquidar' available on a partial entry to pay the rest" do
      patch settle_financial_entry_path(partial)

      expect(partial.reload).to be_settled
      expect(partial.payments.order(:id).map(&:amount_cents)).to eq([30_000, 70_000])
    end

    it "shows the payments link and a 'Liquidar saldo' action" do
      get financial_entries_path

      expect(response.body).to include(financial_entry_payments_path(partial), "Liquidar saldo")
    end

    it "rejects lowering the amount below what was already paid" do
      patch financial_entry_path(partial), params: { financial_entry: { amount_cents: 20_000 } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("não pode ser menor que o já pago")
      expect(partial.reload.amount_cents).to eq(100_000)
    end

    it "accepts an edit that keeps the amount at or above what was paid, without touching the payments" do
      patch financial_entry_path(partial), params: { financial_entry: { amount_cents: 120_000, description: "Ração parcial 2" } }

      expect(response).to redirect_to(financial_entries_path)
      partial.reload
      expect(partial).to have_attributes(amount_cents: 120_000, paid_cents: 30_000, description: "Ração parcial 2")
      expect(partial.payments.count).to eq(1)
    end

    it "shows the paid/balance summary and a payments link on the edit form" do
      get edit_financial_entry_path(partial)

      expect(response.body).to include("Gerenciar pagamentos", "R$ 300,00", "R$ 700,00")
      expect(response.body).not_to include("financial_entry_mark_settled")
    end

    it "offers the 'já liquidado' choice only when creating" do
      get new_financial_entry_path

      expect(response.body).to include("financial_entry_mark_settled")
    end

    it "renders the PDF with the partial status" do
      get financial_entries_path(format: :pdf, status: "partial")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "creating an already-settled entry" do
    it "registers the full payment on the informed settlement date" do
      post financial_entries_path, params: {
        financial_entry: {
          entry_type: "expense", stage: "general", occurred_on: Date.current, amount_cents: 8_000,
          description: "Pago na data", mark_settled: "1", settled_on: Date.current.prev_day
        }
      }

      entry = FinancialEntry.last
      expect(entry.payments.sole).to have_attributes(amount_cents: 8_000, paid_on: Date.current.prev_day)
      expect(entry).to be_settled
    end
  end
end
