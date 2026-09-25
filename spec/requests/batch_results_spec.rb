require "rails_helper"

RSpec.describe "BatchResults", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let!(:batch) { create(:batch, name: "Lote Azul", started_on: Date.new(2026, 1, 1)) }

  before { sign_in user }

  def entry(type, cents, **attrs)
    create(:financial_entry, batch: batch, entry_type: type, amount_cents: cents, occurred_on: Date.new(2026, 8, 10), **attrs)
  end

  describe "GET /batch_results" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get batch_results_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows revenue, cost, result and margin per batch, and the totals" do
      entry("income", 200_000)
      entry("expense", 150_000)

      get batch_results_path

      expect(response).to have_http_status(:ok)
      row = Nokogiri::HTML(response.body).css("tbody tr").find { |tr| tr.text.include?("Lote Azul") }
      expect(row.text).to include("R$ 2.000,00", "R$ 1.500,00", "R$ 500,00", "25,0%")
      expect(Nokogiri::HTML(response.body).at_css("tfoot").text).to include("Total", "R$ 500,00")
    end

    it "colors a losing batch as negative and shows a dash when there is no revenue" do
      entry("expense", 30_000)

      get batch_results_path

      row = Nokogiri::HTML(response.body).css("tbody tr").find { |tr| tr.text.include?("Lote Azul") }
      expect(row.text).to include("-R$ 300,00", "—")
      expect(row.at_css(".text-red-700")).to be_present
    end

    it "links each batch to its Financeiro entries, keeping the period" do
      entry("income", 1_000)

      get batch_results_path, params: { from: "2026-08-01", to: "2026-08-31" }

      link = Nokogiri::HTML(response.body).at_css("tbody a[href*='financial_entries']")
      expect(link["href"]).to include("batch_id=#{batch.id}", "from=2026-08-01", "to=2026-08-31")
    end

    it "applies the status and period filters" do
      closed = create(:batch, name: "Lote Velho", status: "closed")
      entry("income", 1_000)
      create(:financial_entry, batch: closed, entry_type: "income", amount_cents: 1_000, occurred_on: Date.new(2026, 8, 10))

      get batch_results_path, params: { status: "closed" }
      expect(response.body).to include("Lote Velho")
      expect(response.body).not_to include("Lote Azul")

      get batch_results_path, params: { from: "2027-01-01" }
      expect(response.body).to include("Nenhum lote com lançamentos")
    end

    it "mentions the entries that have no batch instead of hiding them" do
      create(:financial_entry, batch: nil, entry_type: "expense", amount_cents: 45_000, occurred_on: Date.new(2026, 8, 10))
      entry("income", 1_000)

      get batch_results_path

      expect(response.body).to include("sem lote", "custo R$ 450,00")
    end

    it "renders a PDF" do
      entry("income", 1_000)

      get batch_results_path(format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end
  end
end
