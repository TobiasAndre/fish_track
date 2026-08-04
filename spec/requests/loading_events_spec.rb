require "rails_helper"

RSpec.describe "LoadingEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }
  let(:customer) { create(:customer) }
  let(:payment_method) { create(:payment_method) }

  before { sign_in user }

  describe "GET /loading_events" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get loading_events_path

      expect(response).to have_http_status(:redirect)
    end

    it "shows a placeholder when no batch is selected" do
      get loading_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Selecione um lote")
    end

    it "shows the form and history for the selected batch stocking" do
      get loading_events_path(batch_stocking_id: batch_stocking.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novo lançamento")
    end
  end

  describe "POST /loading_events" do
    it "creates a loading stocking event, deriving quantity from weight and avg weight" do
      expect do
        post loading_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            customer_id: customer.id,
            payment_method_id: payment_method.id,
            total_weight_kg: 100,
            avg_weight_g: 500,
            tax_percentage: 12.5,
            loading_destination: "Tanque 3",
            gta_number: "123456",
            invoice_number: "987654"
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "loading").count }.by(1)

      expect(response).to redirect_to(loading_events_path(batch_stocking_id: batch_stocking.id))

      event = batch_stocking.stocking_events.where(event_type: "loading").last
      expect(event.quantity).to eq(200) # ceil((100 * 1000) / 500)
      expect(event.tax_percentage.to_f).to eq(12.5)
      expect(event.loading_destination).to eq("Tanque 3")
      expect(event.gta_number).to eq("123456")
      expect(event.invoice_number).to eq("987654")
    end

    it "does not create a loading event without an occurred_on" do
      expect do
        post loading_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: nil,
            total_weight_kg: 100,
            avg_weight_g: 500
          }
        }
      end.not_to change { batch_stocking.stocking_events.where(event_type: "loading").count }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /loading_events/:id" do
    it "updates the loading event" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      patch loading_event_path(event), params: {
        stocking_event: { loading_destination: "Tanque 5" }
      }

      expect(response).to redirect_to(loading_events_path(batch_stocking_id: batch_stocking.id))
      expect(event.reload.loading_destination).to eq("Tanque 5")
    end
  end

  describe "DELETE /loading_events/:id" do
    it "removes the loading event" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      expect do
        delete loading_event_path(event)
      end.to change { batch_stocking.stocking_events.where(event_type: "loading").count }.by(-1)

      expect(response).to redirect_to(loading_events_path(batch_stocking_id: batch_stocking.id))
    end
  end
end
