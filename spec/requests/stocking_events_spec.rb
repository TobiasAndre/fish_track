require "rails_helper"

RSpec.describe "StockingEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }

  before { sign_in user }

  describe "GET .../stocking_events" do
    it "lists the stocking events for the batch stocking" do
      get batch_batch_stocking_stocking_events_path(batch, batch_stocking)

      expect(response).to have_http_status(:ok)
    end

    it "filters by event_type" do
      get batch_batch_stocking_stocking_events_path(batch, batch_stocking), params: { event_type: "mortality" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET .../stocking_events/new" do
    it "renders the new event form" do
      get new_batch_batch_stocking_stocking_event_path(batch, batch_stocking), params: { event_type: "mortality" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST .../stocking_events" do
    it "creates a stocking event scoped to the batch stocking" do
      expect do
        post batch_batch_stocking_stocking_events_path(batch, batch_stocking), params: {
          stocking_event: {
            event_type: "mortality",
            occurred_on: Date.current,
            quantity: 50
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "mortality").count }.by(1)

      expect(response).to redirect_to(batch_batch_stocking_stocking_events_path(batch, batch_stocking))
    end

    it "re-renders the form when occurred_on is missing" do
      post batch_batch_stocking_stocking_events_path(batch, batch_stocking), params: {
        stocking_event: {
          event_type: "mortality",
          occurred_on: nil,
          quantity: 50
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH .../stocking_events/:id" do
    it "updates the stocking event" do
      event = create(:stocking_event, :mortality, batch_stocking: batch_stocking, quantity: 10)

      patch batch_batch_stocking_stocking_event_path(batch, batch_stocking, event), params: {
        stocking_event: { quantity: 20 }
      }

      expect(response).to redirect_to(batch_batch_stocking_stocking_events_path(batch, batch_stocking))
      expect(event.reload.quantity).to eq(20)
    end
  end

  describe "DELETE .../stocking_events/:id" do
    it "removes the stocking event" do
      event = create(:stocking_event, :mortality, batch_stocking: batch_stocking)

      expect do
        delete batch_batch_stocking_stocking_event_path(batch, batch_stocking, event)
      end.to change { batch_stocking.stocking_events.where(event_type: "mortality").count }.by(-1)

      expect(response).to redirect_to(batch_batch_stocking_stocking_events_path(batch, batch_stocking))
    end
  end
end
