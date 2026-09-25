require "rails_helper"

RSpec.describe "SiloStockReports", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:unit) { create(:unit, name: "Unidade Norte") }
  let(:silo) { create(:silo, unit: unit, name: "Silo 1") }
  let(:brand) { create(:feeding_brand, name: "Guabi") }
  let(:feeding_type) { create(:feeding_type, feeding_brand: brand, name: "Ração 32%") }

  before { sign_in user }

  def doc
    Nokogiri::HTML(response.body)
  end

  def section(title)
    heading = doc.css("h2").find { |h| h.text.include?(title) }
    heading.ancestors("div").find { |div| div["class"].to_s.include?("rounded-xl") }
  end

  describe "GET /silo_stock_reports" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get silo_stock_reports_path

      expect(response).to have_http_status(:redirect)
    end

    it "shows an empty state when there are no entries" do
      get silo_stock_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nenhuma entrada de estoque encontrada")
      expect(response.body).to include("Nenhum estoque disponível")
    end

    it "shows the current stock by lote, silo, type and brand with a grand total" do
      batch = create(:batch, name: "Lote Alfa")
      create(:silo_stock_entry, silo: silo, batch: batch, feeding_type: feeding_type, quantity_kg: 300)
      create(:silo_stock_entry, silo: silo, batch: batch, feeding_type: feeding_type, quantity_kg: 200)

      get silo_stock_reports_path

      stock = section("Estoque atual")
      expect(stock.css("thead th").map { |th| th.text.strip }).to eq(%w[Lote Silo Tipo Marca Quantidade])
      row = stock.css("tbody tr").first.css("td").map { |td| td.text.strip }
      expect(row).to eq(["Lote Alfa", "Silo 1", "Ração 32%", "Guabi", "500kg"])
      expect(stock.css("tbody tr").last.text).to include("Total geral").and include("500kg")
    end

    it "lists the history from the newest to the oldest entry, with totals" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, occurred_on: Date.new(2026, 1, 10), quantity_kg: 100, total_cents: 50_000)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, occurred_on: Date.new(2026, 3, 5), quantity_kg: 200, total_cents: 90_000)

      get silo_stock_reports_path

      history = section("Histórico")
      dates = history.css("tbody tr").filter_map { |tr| tr.at_css("td")&.text&.strip }.grep(%r{\A\d{2}/\d{2}/\d{4}\z})
      expect(dates).to eq(%w[05/03/2026 10/01/2026])
      expect(history.css("tbody tr").last.text.gsub(/\s+/, " ")).to include("Total (2 entradas)").and include("300kg").and include("R$ 1.400,00")
    end

    it "filters the history by period, lote, silo, brand and type, but not the current stock" do
      batch = create(:batch, name: "Lote Alfa")
      other_brand = create(:feeding_brand, name: "Purina")
      other_type = create(:feeding_type, feeding_brand: other_brand, name: "Ração Extrusada")
      other_silo = create(:silo, unit: unit, name: "Silo 2")
      create(:silo_stock_entry, silo: silo, batch: batch, feeding_type: feeding_type, occurred_on: Date.new(2026, 6, 15), quantity_kg: 100)
      create(:silo_stock_entry, silo: other_silo, feeding_type: other_type, occurred_on: Date.new(2026, 1, 1), quantity_kg: 700)

      get silo_stock_reports_path, params: { from: "2026-06-01", to: "2026-06-30", batch_id: batch.id, silo_id: silo.id,
                                             feeding_brand_id: brand.id, feeding_type_id: feeding_type.id }

      history = section("Histórico")
      expect(history.css("tbody tr").count).to eq(2) # a entrada + o total
      expect(history.text).not_to include("Ração Extrusada")
      expect(section("Estoque atual").text).to include("Ração Extrusada")
    end

    it "ignores a type filter that does not belong to the filtered brand" do
      other_type = create(:feeding_type, feeding_brand: create(:feeding_brand, name: "Purina"), name: "Ração Extrusada")
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)

      get silo_stock_reports_path, params: { feeding_brand_id: brand.id, feeding_type_id: other_type.id }

      expect(section("Histórico").text).to include("Ração 32%")
    end

    it "renders a PDF" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)

      get silo_stock_reports_path(format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end
  end

  describe "the PDF template" do
    it "shows the same data as the page: filters, current stock and history" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 250, total_cents: 100_000)
      html = ApplicationController.render(
        template: "silo_stock_reports/index", formats: [:pdf], layout: false,
        assigns: {
          report: SiloStockReport.new({}), silos: Silo.includes(:unit), batches: Batch.all, feeding_brands: FeedingBrand.all,
          filter_feeding_types: FeedingType.all.to_a, entries: SiloStockReport.new({}).scope.to_a,
          entries_total_kg: 250, entries_total_cents: 100_000,
          stock_rows: SiloStockReport.new({}).stock_rows, stock_total_kg: 250
        }
      )

      html = html.gsub(/\s+/, " ")
      expect(html).to include("Estoque atual").and include("Historico de entradas").and include("Ração 32%").and include("R$ 1.000,00")
    end
  end

  describe "POST /silo_stock_reports/create_share" do
    it "creates a ReportShare with the current filters and redirects back with report_share_id" do
      batch = create(:batch)

      expect do
        post create_share_silo_stock_reports_path, params: { batch_id: batch.id, from: "2026-06-01" }
      end.to change(ReportShare, :count).by(1)

      report_share = ReportShare.last
      expect(report_share.report_type).to eq("silo_stock_report")
      expect(report_share.filters).to eq("batch_id" => batch.id.to_s, "from" => "2026-06-01")
      expect(response).to redirect_to(silo_stock_reports_path(batch_id: batch.id, from: "2026-06-01", report_share_id: report_share.id))
    end

    it "makes the page open WhatsApp with the public PDF link after redirecting" do
      allow(Apartment::Tenant).to receive(:current).and_return("public")
      company = create(:company, tenant_name: "public")
      create(:membership, user: user, company: company, role: "owner")
      sign_out user
      post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }
      report_share = create(:report_share, report_type: "silo_stock_report", filters: {})

      get silo_stock_reports_path(report_share_id: report_share.id)

      opener = doc.at_css("[data-controller='open-url']")
      expect(opener["data-open-url-url-value"]).to start_with("https://wa.me/?text=")
      expect(CGI.unescape(opener["data-open-url-url-value"])).to include("/shared/public/silo_stock_reports/#{report_share.id}/#{report_share.share_token}.pdf")
    end
  end

  describe "GET /shared/:tenant_name/silo_stock_reports/:id/:share_token" do
    it "renders the PDF publicly, without requiring authentication" do
      sign_out user
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)
      report_share = create(:report_share, report_type: "silo_stock_report", filters: {})

      get shared_silo_stock_report_pdf_path(
        tenant_name: "public", id: report_share.id, share_token: report_share.share_token, format: :pdf
      )

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not found with an invalid share_token" do
      report_share = create(:report_share, report_type: "silo_stock_report")

      get shared_silo_stock_report_pdf_path(
        tenant_name: "public", id: report_share.id, share_token: "wrong-token", format: :pdf
      )

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "access profile" do
    it "is a read-only page in the Relatórios group of the menu" do
      resource = PermissionCatalog.find("silo_stock_reports")

      expect(resource.actions).to eq(%w[read])
      expect(PermissionCatalog::GROUPS.find { |group| group.resources.include?(resource) }.label).to eq("Relatórios")
    end
  end
end
