require "rails_helper"

RSpec.describe "FeedingEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }
  let(:feeding_brand) { create(:feeding_brand, name: "Guabi") }
  let(:feeding_type) { create(:feeding_type, name: "Extrusada 32%", feeding_brand: feeding_brand) }

  before { sign_in user }

  describe "GET /feeding_events" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_events_path

      expect(response).to have_http_status(:redirect)
    end

    it "lists active batch stockings with a launch action when no batch is selected" do
      batch_stocking

      get feeding_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ração por lote ativo")
      expect(response.body).to include(batch_stocking.display_name)
      expect(response.body).to include("Lançar ração")
      expect(response.body).to include(feeding_events_path(batch_stocking_id: batch_stocking.id))
    end

    it "does not list batch stockings from closed batches" do
      batch_stocking
      closed_batch = create(:batch, pond: pond, status: "closed")
      closed_batch_stocking = closed_batch.batch_stockings.first

      get feeding_events_path

      expect(response.body).to include(batch_stocking.display_name)
      expect(response.body).not_to include(closed_batch_stocking.display_name)
    end

    it "shows the form and history for the selected batch stocking" do
      get feeding_events_path(batch_stocking_id: batch_stocking.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novo lançamento de ração")
    end
  end

  describe "POST /feeding_events" do
    it "creates a feeding stocking event associated with the batch stocking" do
      expect do
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            feeding_type_id: feeding_type.id,
            feed_kg: "50",
            total_cents: 25_000
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "feeding").count }.by(1)

      event = batch_stocking.stocking_events.where(event_type: "feeding").last

      expect(response).to redirect_to(feeding_events_path(batch_stocking_id: batch_stocking.id))
      expect(event.feeding_type).to eq(feeding_type)
      expect(event.feeding_brand).to eq(feeding_brand)
      expect(event.feed_kg.to_f).to eq(50.0)
      expect(event.batch_stocking).to eq(batch_stocking)
    end

    it "automatically calculates price_per_kg_cents from total_cents and feed_kg" do
      post feeding_events_path, params: {
        stocking_event: {
          batch_stocking_id: batch_stocking.id,
          occurred_on: Date.current,
          feeding_type_id: feeding_type.id,
          feed_kg: "50",
          total_cents: 25_000
        }
      }

      event = batch_stocking.stocking_events.where(event_type: "feeding").last
      expect(event.price_per_kg_cents).to eq(500)
    end

    it "does not create a financial entry (the expense is recorded when ração enters the silo, not when it's fed)" do
      expect do
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            feeding_type_id: feeding_type.id,
            feed_kg: "50",
            total_cents: 25_000
          }
        }
      end.not_to change(FinancialEntry, :count)
    end

    it "does not create a feeding event without a positive feed_kg" do
      expect do
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            feeding_type_id: feeding_type.id,
            feed_kg: "0",
            total_cents: 25_000
          }
        }
      end.not_to change { batch_stocking.stocking_events.where(event_type: "feeding").count }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a feeding event without a feeding type or brand" do
      expect do
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            feed_kg: "50",
            total_cents: 25_000
          }
        }
      end.not_to change { batch_stocking.stocking_events.where(event_type: "feeding").count }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a feeding event for a closed batch" do
      batch.update!(status: "closed")

      expect do
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            feeding_type_id: feeding_type.id,
            feed_kg: "50",
            total_cents: 25_000
          }
        }
      end.not_to change { StockingEvent.where(event_type: "feeding").count }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "supports multiple feeding launches for the same batch" do
      3.times do |n|
        post feeding_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current - n.days,
            feeding_type_id: feeding_type.id,
            feed_kg: "10",
            total_cents: 5_000
          }
        }
      end

      expect(batch_stocking.stocking_events.where(event_type: "feeding").count).to eq(3)
    end
  end

  describe "GET /feeding_events/:id/edit" do
    it "renders the form pre-filled with the event data" do
      event = create(:stocking_event, :feeding, batch_stocking: batch_stocking, feeding_type: feeding_type)

      get edit_feeding_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Editar lançamento")
      expect(response.body).to include(
        %(<option selected="selected" value="#{feeding_type.id}">#{feeding_type.name}</option>)
      )
    end
  end

  describe "PATCH /feeding_events/:id" do
    it "updates the feeding event" do
      event = create(:stocking_event, :feeding, batch_stocking: batch_stocking, feed_kg: 50, total_cents: 25_000)

      patch feeding_event_path(event), params: {
        stocking_event: { feed_kg: "100" }
      }

      expect(response).to redirect_to(feeding_events_path(batch_stocking_id: batch_stocking.id))
      expect(event.reload.feed_kg.to_f).to eq(100.0)
    end

    it "does not touch the Financeiro module when the event is edited" do
      event = create(:stocking_event, :feeding, batch_stocking: batch_stocking, feed_kg: 50, total_cents: 25_000)

      expect do
        patch feeding_event_path(event), params: {
          stocking_event: { total_cents: 40_000 }
        }
      end.not_to change(FinancialEntry, :count)
    end

    it "recalculates price_per_kg_cents after an edit" do
      event = create(:stocking_event, :feeding, batch_stocking: batch_stocking, feed_kg: 50, total_cents: 25_000)

      patch feeding_event_path(event), params: {
        stocking_event: { feed_kg: "100" }
      }

      expect(event.reload.price_per_kg_cents).to eq(250)
    end
  end

  describe "DELETE /feeding_events/:id" do
    it "removes the feeding event without touching the Financeiro module" do
      event = create(:stocking_event, :feeding, batch_stocking: batch_stocking, feed_kg: 50, total_cents: 25_000)

      expect do
        delete feeding_event_path(event)
      end.to change { batch_stocking.stocking_events.where(event_type: "feeding").count }.by(-1)

      expect(response).to redirect_to(feeding_events_path(batch_stocking_id: batch_stocking.id))
      expect(FinancialEntry.count).to eq(0)
    end
  end
end
