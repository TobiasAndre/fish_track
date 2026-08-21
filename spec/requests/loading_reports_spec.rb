require "rails_helper"

RSpec.describe "LoadingReports", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }
  let(:customer) { create(:customer) }
  let(:integrated) { create(:integrated, customer: customer) }

  before { sign_in user }

  describe "GET /loading_reports" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get loading_reports_path

      expect(response).to have_http_status(:redirect)
    end

    it "shows an empty state when there are no loading events" do
      get loading_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nenhum carregamento encontrado")
    end

    it "lists loading events with their batch, pond and totals" do
      event = create(
        :stocking_event, :loading,
        batch_stocking: batch_stocking, customer: customer, integrated: integrated,
        occurred_on: Date.new(2026, 6, 15)
      )

      get loading_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(batch.name)
      expect(response.body).to include(pond.name)
      expect(response.body).to include(customer.name)
      expect(response.body).to include(integrated.name)
      expect(response.body).to include(I18n.l(event.occurred_on))
    end

    it "does not include mortality or biometry events" do
      create(:stocking_event, :mortality, batch_stocking: batch_stocking, notes: "Mortalidade única")

      get loading_reports_path

      expect(response.body).not_to include("Mortalidade única")
    end

    it "filters by period" do
      inside = create(:stocking_event, :loading, batch_stocking: batch_stocking, occurred_on: Date.new(2026, 6, 15), notes: "Dentro do período")
      outside = create(:stocking_event, :loading, batch_stocking: batch_stocking, occurred_on: Date.new(2026, 1, 1), notes: "Fora do período")

      get loading_reports_path, params: { start_date: "2026-06-01", end_date: "2026-06-30" }

      expect(response.body).to include(inside.notes)
      expect(response.body).not_to include(outside.notes)
    end

    it "filters by produtor (integrado)" do
      other_integrated = create(:integrated, customer: customer)
      matching = create(:stocking_event, :loading, batch_stocking: batch_stocking, integrated: integrated, notes: "Do produtor filtrado")
      other = create(:stocking_event, :loading, batch_stocking: batch_stocking, integrated: other_integrated, notes: "De outro produtor")

      get loading_reports_path, params: { integrated_id: integrated.id }

      expect(response.body).to include(matching.notes)
      expect(response.body).not_to include(other.notes)
    end

    it "filters by lote" do
      other_batch = create(:batch, pond: pond)
      other_batch_stocking = other_batch.batch_stockings.first

      matching = create(:stocking_event, :loading, batch_stocking: batch_stocking, notes: "Do lote filtrado")
      other = create(:stocking_event, :loading, batch_stocking: other_batch_stocking, notes: "De outro lote")

      get loading_reports_path, params: { batch_id: batch.id }

      expect(response.body).to include(matching.notes)
      expect(response.body).not_to include(other.notes)
    end

    it "filters by tanque" do
      other_pond = create(:pond, unit: unit)
      other_batch = create(:batch, pond: other_pond)
      other_batch_stocking = other_batch.batch_stockings.first

      matching = create(:stocking_event, :loading, batch_stocking: batch_stocking, notes: "Do tanque filtrado")
      other = create(:stocking_event, :loading, batch_stocking: other_batch_stocking, notes: "De outro tanque")

      get loading_reports_path, params: { pond_id: pond.id }

      expect(response.body).to include(matching.notes)
      expect(response.body).not_to include(other.notes)
    end

    it "sums the quantity, weight and value of the filtered events" do
      # quantity is derived from total_weight_kg / avg_weight_g, and total_cents
      # from total_weight_kg * price_per_kg_cents -- both computed by the model.
      create(
        :stocking_event, :loading, batch_stocking: batch_stocking,
        total_weight_kg: 50, avg_weight_g: 500, price_per_kg_cents: 1_000
      )
      create(
        :stocking_event, :loading, batch_stocking: batch_stocking,
        total_weight_kg: 75, avg_weight_g: 500, price_per_kg_cents: 1_000
      )

      get loading_reports_path

      expect(response.body).to include("250")
      expect(response.body).to include("125,000")
      expect(response.body).to include("R$  1.250,00")
    end

    it "renders a PDF" do
      create(:stocking_event, :loading, batch_stocking: batch_stocking)

      get loading_reports_path(format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end
  end
end
