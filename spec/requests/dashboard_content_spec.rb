require "rails_helper"

RSpec.describe "Dashboard content", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let!(:batch) { create(:batch, name: "Lote Azul", stocking_quantity: 4_000) }

  before do
    # O dashboard exige uma empresa escolhida (tenant diferente de "public").
    company = create(:company, tenant_name: "public")
    create(:membership, user: user, company: company, role: "owner")
    post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }
    allow(Apartment::Tenant).to receive(:current).and_return("acme")
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def card_value(label)
    doc.css("p").find { |p| p.text.strip == label }.next_element.text.strip
  end

  it "shows the six totals for the active lotes, side by side in one row" do
    stocking = batch.batch_stockings.first
    create(:stocking_event, :loading, batch_stocking: stocking).update_columns(quantity: 1_500)
    create(:financial_entry, batch: batch, entry_type: "expense", amount_cents: 250_000)
    create(:financial_entry, batch: batch, entry_type: "income", amount_cents: 900_000)
    closed = create(:batch, status: "closed", stocking_quantity: 7_000)
    create(:financial_entry, batch: closed, entry_type: "expense", amount_cents: 111_100)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(card_value("Peixes alojados")).to eq("4.000")
    expect(card_value("Peixes entregues")).to eq("1.500")
    expect(card_value("Despesa total")).to eq("R$ 2.500,00")
    expect(card_value("Faturamento total")).to eq("R$ 9.000,00")
    expect(card_value("Peixes a entregar")).to eq("2.500")   # 4.000 alojados - 1.500 entregues
    expect(card_value("Saldo financeiro")).to eq("R$ 6.500,00") # 9.000 faturamento - 2.500 despesa
    expect(response.body).to include("Somando os 1 lote ativo")

    labels = doc.css("p").map { |p| p.text.strip }
    row = %w[Peixes\ alojados Peixes\ entregues Peixes\ a\ entregar Despesa\ total Faturamento\ total Saldo\ financeiro]
    expect(labels.select { |t| row.include?(t) }).to eq(row)

    grid = doc.css("p").find { |p| p.text.strip == "Peixes alojados" }.ancestors("div.grid").first
    expect(grid["class"]).to include("lg:grid-cols-6")
    expect(grid.css("> div").size).to eq(6)
  end

  it "shows a negative saldo in red and a positive one in green" do
    create(:financial_entry, batch: batch, entry_type: "expense", amount_cents: 300_000)
    create(:financial_entry, batch: batch, entry_type: "income", amount_cents: 100_000)

    get root_path

    saldo = doc.css("p").find { |p| p.text.strip == "Saldo financeiro" }.next_element
    expect(saldo.text.strip).to eq("-R$ 2.000,00")
    expect(saldo["class"]).to include("text-red-700")

    create(:financial_entry, batch: batch, entry_type: "income", amount_cents: 400_000)
    get root_path

    saldo = doc.css("p").find { |p| p.text.strip == "Saldo financeiro" }.next_element
    expect(saldo.text.strip).to eq("R$ 2.000,00")
    expect(saldo["class"]).to include("text-green-700")
  end

  it "shows zero peixes a entregar when everything was delivered" do
    create(:stocking_event, :loading, batch_stocking: batch.batch_stockings.first).update_columns(quantity: 4_000)

    get root_path

    expect(card_value("Peixes a entregar")).to eq("0")
  end

  it "shows loaded quantity, expense and revenue on each active lote" do
    create(:stocking_event, :loading, batch_stocking: batch.batch_stockings.first).update_columns(quantity: 800)
    create(:financial_entry, batch: batch, entry_type: "expense", amount_cents: 30_000)
    create(:financial_entry, batch: batch, entry_type: "income", amount_cents: 55_000)

    get root_path

    card = doc.css("a").find { |a| a.text.include?("Lote Azul") }
    expect(card.text.gsub(/\s+/, " ")).to include("Carregado: 800", "Despesa: R$ 300,00", "Faturamento: R$ 550,00")
  end

  it "lists each active lote's tanks by the tank order_number" do
    unit = create(:unit, name: "Sede")
    pond_9 = create(:pond, unit: unit, name: "Tanque 9", order_number: 3)
    pond_4 = create(:pond, unit: unit, name: "Tanque 4", order_number: 1)
    pond_7 = create(:pond, unit: unit, name: "Tanque 7", order_number: 2)
    multi = create(:batch, name: "Lote Multi", pond: pond_9)
    [pond_7, pond_4].each { |pond| multi.batch_stockings.create!(pond: pond, quantity: 100, avg_weight_g: 1, stocked_on: Date.current) }

    get root_path

    card = doc.css("a").find { |a| a.text.include?("Lote Multi") }
    expect(card.text.gsub(/\s+/, " ")).to include("Sede • Tanque: Tanque 4, Tanque 7, Tanque 9")
  end

  it "no longer shows the recent events" do
    create(:stocking_event, :mortality, batch_stocking: batch.batch_stockings.first)

    get root_path

    expect(response.body).not_to include("Eventos recentes")
  end

  describe "open payables and receivables" do
    def table(title)
      doc.css("h2").find { |h| h.text.strip == title }.ancestors("div.rounded-xl").first
    end

    it "lists what is left to pay and to receive, each ordered by due date, as item and balance" do
      create(:financial_entry, entry_type: "expense", description: "Ração maio", amount_cents: 80_000, due_on: Date.current + 20)
      create(:financial_entry, entry_type: "expense", description: "Energia", amount_cents: 30_000, due_on: Date.current + 5)
      create(:financial_entry, entry_type: "income", description: "Venda Azul", amount_cents: 500_000, due_on: Date.current + 9)
      create(:financial_entry, entry_type: "income", description: "Venda Verde", amount_cents: 200_000, due_on: Date.current + 2)

      get root_path

      pay_rows = table("A pagar").css("tbody tr").map { |tr| tr.text.gsub(/\s+/, " ").strip }
      expect(pay_rows.size).to eq(2)
      expect(pay_rows.first).to include("Energia", "R$ 300,00")
      expect(pay_rows.last).to include("Ração maio", "R$ 800,00")
      expect(table("A pagar").at_css("tfoot").text.gsub(/\s+/, " ")).to include("Total em aberto", "R$ 1.100,00")

      receive_rows = table("A receber").css("tbody tr").map { |tr| tr.text.gsub(/\s+/, " ").strip }
      expect(receive_rows.first).to include("Venda Verde", "R$ 2.000,00")
      expect(receive_rows.last).to include("Venda Azul", "R$ 5.000,00")
    end

    it "shows only the balance still open of a partially paid entry, and leaves settled ones out" do
      partial = create(:financial_entry, entry_type: "expense", description: "Parcial", amount_cents: 100_000, due_on: Date.current + 3)
      partial.payments.create!(paid_on: Date.current, amount_cents: 40_000)
      create(:financial_entry, entry_type: "expense", description: "Quitada", amount_cents: 50_000).settle!

      get root_path

      rows = table("A pagar").css("tbody tr").map { |tr| tr.text.gsub(/\s+/, " ") }
      expect(rows.size).to eq(1)
      expect(rows.first).to include("Parcial", "R$ 600,00")
      expect(response.body).not_to include("Quitada")
    end

    it "flags overdue items" do
      create(:financial_entry, entry_type: "income", description: "Atrasado", amount_cents: 10_000, due_on: Date.current - 4)

      get root_path

      row = table("A receber").at_css("tbody tr")
      expect(row.text).to include("Vencido em")
      expect(row["class"]).to include("bg-amber-50")
    end

    it "limits each table to 10 items and says how many exist, linking to the filtered Financeiro" do
      12.times { |i| create(:financial_entry, entry_type: "expense", description: "Conta #{i}", amount_cents: 1_000, due_on: Date.current + i) }

      get root_path

      expect(table("A pagar").css("tbody tr").size).to eq(10)
      expect(table("A pagar").at_css("tfoot").text).to include("10 de 12 itens", "R$ 120,00")
      link = table("A pagar").at_css("a[href*='financial_entries']")
      expect(link["href"]).to include("entry_type=expense", "status=pending")
    end

    it "shows an empty message when nothing is open" do
      get root_path

      expect(response.body).to include("Nada a pagar em aberto.", "Nada a receber em aberto.")
    end
  end
end
