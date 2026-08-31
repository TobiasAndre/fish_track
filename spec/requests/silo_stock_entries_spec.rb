require "rails_helper"

RSpec.describe "SiloStockEntries", type: :request do
  let(:user) { create(:user) }
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

    it "shows the current stock summary as the sum of entries per silo and type" do
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 300)
      create(:silo_stock_entry, silo: silo, feeding_type: feeding_type, quantity_kg: 200)

      get silo_stock_entries_path

      expect(response.body).to include("Estoque atual")
      expect(response.body).to include("500,000kg")
    end

    it "filters the history by silo" do
      matching = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)
      other_entry = create(:silo_stock_entry)

      get silo_stock_entries_path, params: { silo_id: silo.id }

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
