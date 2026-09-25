require "rails_helper"

RSpec.describe "SiloStockEntries", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:unit) { create(:unit) }
  let(:silo) { create(:silo, unit: unit, name: "Silo Norte") }
  let(:feeding_brand) { create(:feeding_brand, name: "Guabi") }
  let(:feeding_type) { create(:feeding_type, name: "Extrusada 32%", feeding_brand: feeding_brand) }

  before { sign_in user }

  describe "GET /silo_stock_entries" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get silo_stock_entries_path

      expect(response).to have_http_status(:redirect)
    end

    it "renders the form and history" do
      get silo_stock_entries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nova entrada de estoque")
      expect(response.body).to include("Histórico")
    end

    it "lists entries with silo, unit, type and brand" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      get silo_stock_entries_path

      expect(response.body).to include(entry.silo.name)
      expect(response.body).to include(unit.name)
      expect(response.body).to include(feeding_type.name)
      expect(response.body).to include(feeding_brand.name)
    end

    def current_stock_section(body)
      doc = Nokogiri::HTML(body)
      doc.css("h2").find { |h| h.text.include?("Estoque atual") }&.parent
    end

    it "shows the current stock summary as the sum of entries per silo and type" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 300)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 200)

      get silo_stock_entries_path

      section = current_stock_section(response.body)
      expect(section).to be_present
      expect(section.css("tbody tr").count).to eq(1)
      expect(section.text).to include(silo.name)
      expect(section.text).to include("500kg")
    end

    it "shows the lote instead of the unit in the current stock, one row per lote" do
      batch_a = create(:batch, name: "Lote Alfa")
      batch_b = create(:batch, name: "Lote Beta")
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, batch: batch_a, quantity_kg: 300)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, batch: batch_b, quantity_kg: 200)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, batch: batch_b, quantity_kg: 50)

      get silo_stock_entries_path

      section = current_stock_section(response.body)
      expect(section.css("thead th").map { |th| th.text.strip }).to eq(%w[Lote Silo Tipo Marca Quantidade])
      rows = section.css("tbody tr").map { |tr| tr.css("td").map { |td| td.text.strip } }
      expect(rows.map { |r| [r[0], r[4]] }).to eq([["Lote Alfa", "300kg"], ["Lote Beta", "250kg"]])
    end

    it "lists the history from the newest to the oldest entry" do
      old_type = create(:feeding_type, feeding_brand: feeding_brand, name: "Racao Antiga")
      new_type = create(:feeding_type, feeding_brand: feeding_brand, name: "Racao Recente")
      create(:silo_stock_entry, silo: silo, feeding_type: old_type, occurred_on: Date.new(2026, 1, 10))
      create(:silo_stock_entry, silo: silo, feeding_type: new_type, occurred_on: Date.new(2026, 3, 5))

      get silo_stock_entries_path

      dates = Nokogiri::HTML(response.body).css("tbody tr").filter_map { |tr| tr.at_css("td")&.text&.strip }.grep(%r{\A\d{2}/\d{2}/\d{4}\z})
      expect(dates).to eq(%w[05/03/2026 10/01/2026])
    end

    it "shows a grand total at the end of the current stock table" do
      other_type = create(:feeding_type, feeding_brand: feeding_brand)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 300)
      create(:silo_stock_entry, silo: nil, feeding_type: other_type, quantity_kg: 450)

      get silo_stock_entries_path

      footer = current_stock_section(response.body).css("tfoot tr").first
      expect(footer.text).to include("Total geral")
      expect(footer.text).to include("750kg")
    end

    it "includes in the current stock entries that were recorded without a silo" do
      create(:silo_stock_entry, silo: nil, feeding_type: feeding_type, quantity_kg: 750)

      get silo_stock_entries_path

      section = current_stock_section(response.body)
      expect(section).to be_present
      row = section.css("tbody tr").first
      expect(row).to be_present
      expect(row.text).to include("Sem silo")
      expect(row.text).to include("750kg")
    end

    def history_total_row(body)
      Nokogiri::HTML(body).css("tfoot tr").map { |r| r.text.gsub(/\s+/, " ").strip }.grep(/Total \(/).first
    end

    it "shows the weight and value totals of the whole history" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 1_000, total_cents: 50_000)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500,   total_cents: 25_000)

      get silo_stock_entries_path

      row = history_total_row(response.body)
      expect(row).to include("Total (2 entradas)")
      expect(row).to include("1.500kg")
      expect(row).to include("R$ 750,00")
    end

    it "totals only the filtered entries" do
      other_brand = create(:feeding_brand, name: "Purina")
      other_type = create(:feeding_type, feeding_brand: other_brand)

      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 1_000, total_cents: 50_000)
      create(:silo_stock_entry, silo: silo, feeding_type: other_type, quantity_kg: 3_000, total_cents: 90_000)

      get silo_stock_entries_path, params: { feeding_brand_id: feeding_brand.id }

      row = history_total_row(response.body)
      expect(row).to include("Total (1 entrada)")
      expect(row).to include("1.000kg")
      expect(row).to include("R$ 500,00")
      expect(row).not_to include("4.000kg")
    end

    it "filters the history by silo" do
      matching = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)
      other_entry = create(:silo_stock_entry)

      get silo_stock_entries_path, params: { silo_id: silo.id }

      expect(response.body).to include(edit_silo_stock_entry_path(matching))
      expect(response.body).not_to include(edit_silo_stock_entry_path(other_entry))
    end

    it "filters the history by batch" do
      batch = create(:batch)
      matching = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, batch: batch)
      other_entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)

      get silo_stock_entries_path, params: { batch_id: batch.id }

      expect(response.body).to include(edit_silo_stock_entry_path(matching))
      expect(response.body).not_to include(edit_silo_stock_entry_path(other_entry))
    end

    it "filters the history by feeding brand" do
      other_brand = create(:feeding_brand, name: "Purina")
      other_type = create(:feeding_type, name: "Extrusada 28%", feeding_brand: other_brand)

      matching = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)
      other_entry = create(:silo_stock_entry, silo: silo, feeding_type: other_type)

      get silo_stock_entries_path, params: { feeding_brand_id: feeding_brand.id }

      expect(response.body).to include(edit_silo_stock_entry_path(matching))
      expect(response.body).not_to include(edit_silo_stock_entry_path(other_entry))
    end

    it "restricts the history type filter to the selected brand's types" do
      feeding_type # ensure the brand has a type
      other_brand = create(:feeding_brand, name: "Purina")
      other_type = create(:feeding_type, name: "Extrusada 28%", feeding_brand: other_brand)

      get silo_stock_entries_path, params: { feeding_brand_id: feeding_brand.id }

      type_select = Nokogiri::HTML(response.body).at('select[name="feeding_type_id"]')
      option_labels = type_select.css("option").map(&:text)

      expect(option_labels).to include(feeding_type.name)
      expect(option_labels).not_to include(other_type.name)
    end

    it "drops a stale type filter that does not belong to the selected brand" do
      other_brand = create(:feeding_brand, name: "Purina")
      other_type = create(:feeding_type, name: "Extrusada 28%", feeding_brand: other_brand)

      matching = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)
      other_entry = create(:silo_stock_entry, silo: silo, feeding_type: other_type)

      get silo_stock_entries_path, params: { feeding_brand_id: feeding_brand.id, feeding_type_id: other_type.id }

      # brand wins; the mismatched type filter is ignored, so the brand's entry still shows
      expect(response.body).to include(edit_silo_stock_entry_path(matching))
      expect(response.body).not_to include(edit_silo_stock_entry_path(other_entry))
    end

    it "filters the history by period" do
      inside = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, occurred_on: Date.new(2026, 1, 15))
      outside = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, occurred_on: Date.new(2026, 3, 1))

      get silo_stock_entries_path, params: { from: "2026-01-01", to: "2026-01-31" }

      expect(response.body).to include(I18n.l(inside.occurred_on))
      expect(response.body).not_to include(I18n.l(outside.occurred_on))
    end
  end

  describe "Turbo Frame (only the affected area reloads)" do
    def frame
      Nokogiri::HTML(response.body).at_css("turbo-frame#silo_stock")
    end

    def valid_params(**overrides)
      { silo_stock_entry: { silo_id: silo.id, feeding_type_id: feeding_type.id, occurred_on: Date.current,
                            quantity_kg: 500, total_cents: 250_000 }.merge(overrides) }
    end

    it "wraps the form, current stock and history in one frame that advances the URL, keeping the heading outside" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      get silo_stock_entries_path

      expect(frame["data-turbo-action"]).to eq("advance")
      expect(frame.text).to include("Nova entrada de estoque", "Estoque atual", "Histórico")
      expect(frame.at_css("select#silo_id")).to be_present
      expect(Nokogiri::HTML(response.body).at_css("h1").ancestors("turbo-frame")).to be_empty
    end

    it "makes saving, updating and deleting replace the history entry instead of stacking the same URL" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      get silo_stock_entries_path

      expect(frame.at_css("form[action='#{silo_stock_entries_path}']")["data-turbo-action"]).to eq("replace")
      expect(frame.css("a[data-turbo-method=delete]").map { |a| a["data-turbo-action"] }.uniq).to eq(["replace"])
    end

    it "keeps the links to register brands/types and the paging inside the right place" do
      get silo_stock_entries_path
      FeedingType.destroy_all
      get silo_stock_entries_path

      links = frame.css("a[href='#{new_feeding_brand_path}'], a[href='#{new_feeding_type_path}']")
      expect(links.size).to eq(2)
      expect(links.map { |a| a["data-turbo-frame"] }.uniq).to eq(["_top"])
    end

    it "paginates inside the frame (page links have no frame override)" do
      create_list(:silo_stock_entry, 16, silo: silo, feeding_type: feeding_type, quantity_kg: 10, total_cents: 1_000)

      get silo_stock_entries_path

      page_links = frame.css("a[href*='page=']")
      expect(page_links).not_to be_empty
      expect(page_links.map { |a| a["data-turbo-frame"] }.compact).to be_empty
    end

    it "renders the flash toast inside the frame, once, after a save" do
      post silo_stock_entries_path, params: valid_params
      follow_redirect!

      toasts = Nokogiri::HTML(response.body).css('[data-controller="flash"]')
      expect(toasts.size).to eq(1)
      expect(toasts.sole["data-flash-message-value"]).to eq("Estoque lançado com sucesso.")
      expect(toasts.sole.ancestors("turbo-frame").map { |f| f["id"] }).to include("silo_stock")
    end

    it "answers the frame request after a save with just the frame, the updated stock and the toast, without the app layout" do
      post silo_stock_entries_path, params: valid_params, headers: { "Turbo-Frame" => "silo_stock" }
      follow_redirect!(headers: { "Turbo-Frame" => "silo_stock" }) if response.redirect?

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#silo_stock")).to be_present
      expect(doc.css("nav")).to be_empty
      expect(doc.css('[data-controller="flash"]').size).to eq(1)
      expect(doc.text).to include("Estoque atual", "500")
    end

    it "shows validation errors inside the frame on a failed save" do
      post silo_stock_entries_path, params: valid_params(quantity_kg: ""), headers: { "Turbo-Frame" => "silo_stock" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(frame.text).to include("Não foi possível salvar")
    end

    it "opens an edit and applies filters inside the frame" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      get edit_silo_stock_entry_path(entry), headers: { "Turbo-Frame" => "silo_stock" }
      expect(frame.text).to include("Editar lançamento")

      get silo_stock_entries_path(silo_id: silo.id), headers: { "Turbo-Frame" => "silo_stock" }
      expect(frame.text).to include("Histórico")
    end
  end

  describe "POST /silo_stock_entries" do
    it "creates a silo stock entry" do
      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            silo_id: silo.id,
            feeding_type_id: feeding_type.id,
            occurred_on: Date.current,
            quantity_kg: "500",
            total_cents: 250_000
          }
        }
      end.to change(SiloStockEntry, :count).by(1)

      expect(response).to redirect_to(silo_stock_entries_path)

      entry = SiloStockEntry.last
      expect(entry.silo).to eq(silo)
      expect(entry.feeding_type).to eq(feeding_type)
      expect(entry.feeding_brand).to eq(feeding_brand)
      expect(entry.quantity_kg.to_f).to eq(500.0)
    end

    it "automatically calculates price_per_kg_cents from total_cents and quantity_kg" do
      post silo_stock_entries_path, params: {
        silo_stock_entry: {
          silo_id: silo.id,
          feeding_type_id: feeding_type.id,
          occurred_on: Date.current,
          quantity_kg: "500",
          total_cents: 250_000
        }
      }

      expect(SiloStockEntry.last.price_per_kg_cents).to eq(500)
    end

    it "creates exactly one matching financial entry for the stock entry" do
      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            silo_id: silo.id,
            feeding_type_id: feeding_type.id,
            occurred_on: Date.current,
            quantity_kg: "500",
            total_cents: 250_000
          }
        }
      end.to change(FinancialEntry, :count).by(1)

      entry = SiloStockEntry.last
      expect(entry.financial_entry.amount_cents).to eq(250_000)
      expect(entry.financial_entry.entry_type).to eq("expense")
      expect(entry.financial_entry.unit_id).to eq(unit.id)
    end

    it "does not create an entry without a positive quantity_kg" do
      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            silo_id: silo.id,
            feeding_type_id: feeding_type.id,
            occurred_on: Date.current,
            quantity_kg: "0",
            total_cents: 250_000
          }
        }
      end.not_to change(SiloStockEntry, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create an entry without a feeding type" do
      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            occurred_on: Date.current,
            quantity_kg: "500",
            total_cents: 250_000
          }
        }
      end.not_to change(SiloStockEntry, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "stores the payment method and term, computing due_on from the term" do
      payment_method = create(:payment_method)
      payment_term = create(:payment_term, days: 30)

      post silo_stock_entries_path, params: {
        silo_stock_entry: {
          silo_id: silo.id,
          feeding_type_id: feeding_type.id,
          payment_method_id: payment_method.id,
          payment_term_id: payment_term.id,
          due_on: "2026-09-30", # ignorado: com condição, o vencimento vem dela
          occurred_on: "2026-01-10",
          quantity_kg: "500",
          total_cents: 250_000
        }
      }

      entry = SiloStockEntry.last
      expect(entry.payment_method).to eq(payment_method)
      expect(entry.payment_term).to eq(payment_term)
      expect(entry.due_on).to eq(Date.new(2026, 1, 10) + 30)
    end

    it "keeps the informed due_on when no payment term is selected" do
      post silo_stock_entries_path, params: {
        silo_stock_entry: {
          silo_id: silo.id,
          feeding_type_id: feeding_type.id,
          due_on: "2026-09-30",
          occurred_on: "2026-01-10",
          quantity_kg: "500",
          total_cents: 250_000
        }
      }

      expect(SiloStockEntry.last.due_on).to eq(Date.new(2026, 9, 30))
    end

    it "generates the installment schedule from the selected payment term" do
      term = create(:payment_term, name: "3x", days: 30, installments_count: 3, interval_days: 30)

      post silo_stock_entries_path, params: {
        silo_stock_entry: {
          silo_id: silo.id,
          feeding_type_id: feeding_type.id,
          payment_term_id: term.id,
          occurred_on: "2026-01-01",
          quantity_kg: "500",
          total_cents: 300_000
        }
      }

      entry = SiloStockEntry.last
      expect(entry.financial_entries.count).to eq(3)
      expect(entry.financial_entries.sum(:amount_cents)).to eq(300_000)
      expect(entry.financial_entries.order(:occurred_on).last.occurred_on).to eq(Date.new(2026, 1, 1) + 90)
      expect(entry.due_on).to eq(Date.new(2026, 1, 1) + 30)
    end

    it "creates an entry without a silo, linked to an existing batch" do
      batch = create(:batch)

      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            feeding_type_id: feeding_type.id,
            batch_id: batch.id,
            occurred_on: Date.current,
            quantity_kg: "500",
            total_cents: 250_000
          }
        }
      end.to change(SiloStockEntry, :count).by(1)

      expect(response).to redirect_to(silo_stock_entries_path)

      entry = SiloStockEntry.last
      expect(entry.silo).to be_nil
      expect(entry.batch).to eq(batch)
      expect(entry.financial_entry.batch_id).to eq(batch.id)
    end

    it "does not create an entry referencing a nonexistent silo" do
      expect do
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            silo_id: silo.id + 1000,
            feeding_type_id: feeding_type.id,
            occurred_on: Date.current,
            quantity_kg: "500",
            total_cents: 250_000
          }
        }
      end.not_to change(SiloStockEntry, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "supports multiple entries for the same silo" do
      3.times do |n|
        post silo_stock_entries_path, params: {
          silo_stock_entry: {
            silo_id: silo.id,
            feeding_type_id: feeding_type.id,
            occurred_on: Date.current - n.days,
            quantity_kg: "100",
            total_cents: 50_000
          }
        }
      end

      expect(silo.stock_entries.count).to eq(3)
      expect(FinancialEntry.where(silo_stock_entry_id: silo.stock_entries.select(:id)).count).to eq(3)
    end
  end

  describe "GET /silo_stock_entries/:id/edit" do
    it "renders the form pre-filled with the entry data" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)

      get edit_silo_stock_entry_path(entry)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Editar lançamento")
      expect(response.body).to include(
        %(<option selected="selected" value="#{silo.id}">#{silo.name}</option>)
      )
    end
  end

  describe "PATCH /silo_stock_entries/:id" do
    it "updates the entry" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      patch silo_stock_entry_path(entry), params: {
        silo_stock_entry: { quantity_kg: "1000" }
      }

      expect(response).to redirect_to(silo_stock_entries_path)
      expect(entry.reload.quantity_kg.to_f).to eq(1000.0)
    end

    it "does not create a duplicate financial entry when the entry is edited" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      expect do
        patch silo_stock_entry_path(entry), params: {
          silo_stock_entry: { total_cents: 400_000 }
        }
      end.not_to change(FinancialEntry, :count)

      expect(entry.reload.financial_entry.amount_cents).to eq(400_000)
    end

    it "recalculates price_per_kg_cents after an edit" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)

      patch silo_stock_entry_path(entry), params: {
        silo_stock_entry: { quantity_kg: "1000" }
      }

      expect(entry.reload.price_per_kg_cents).to eq(250)
    end
  end

  describe "DELETE /silo_stock_entries/:id" do
    it "removes the entry and its financial entry" do
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 500, total_cents: 250_000)
      financial_entry = entry.financial_entry

      expect do
        delete silo_stock_entry_path(entry)
      end.to change(SiloStockEntry, :count).by(-1)
        .and change(FinancialEntry, :count).by(-1)

      expect(response).to redirect_to(silo_stock_entries_path)
      expect(FinancialEntry.exists?(financial_entry.id)).to be false
    end
  end
end
