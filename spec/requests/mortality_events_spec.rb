require "rails_helper"

RSpec.describe "MortalityEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }

  before { sign_in user }

  describe "GET /mortality_events" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get mortality_events_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists every active batch stocking with its history when no batch is selected" do
      batch_stocking

      get mortality_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(batch_stocking.display_name)
    end

    it "filters the active batches by pond" do
      other_pond = create(:pond, unit: unit)
      other_batch = create(:batch, pond: other_pond)
      batch_stocking

      get mortality_events_path, params: { pond_id: other_pond.id }

      expect(response.body).to include(other_batch.batch_stockings.first.display_name)
      expect(response.body).not_to include(batch_stocking.display_name)
    end

    it "shows the form and history for the selected batch stocking" do
      get mortality_events_path(batch_stocking_id: batch_stocking.id)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /mortality_events" do
    it "creates a mortality stocking event and deducts it from the current balance" do
      expect do
        post mortality_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            quantity: 100
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "mortality").count }.by(1)

      expect(response).to redirect_to(mortality_events_path(batch_stocking_id: batch_stocking.id))
      expect(batch_stocking.reload.current_quantity).to eq(900)
    end

    it "re-renders the form with errors when the batch stocking is missing" do
      post mortality_events_path, params: {
        stocking_event: {
          batch_stocking_id: nil,
          occurred_on: Date.current,
          quantity: 100
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "editing an existing mortality event" do
    let(:event) do
      create(:stocking_event,
        event_type: "mortality",
        batch_stocking: batch_stocking,
        occurred_on: Date.current,
        quantity: 100)
    end

    it "renders the edit form" do
      get edit_mortality_event_path(event)

      expect(response).to have_http_status(:ok)
    end

    it "updates the mortality event and rebuilds the batch balance" do
      event # 1000 - 100 = 900

      patch mortality_event_path(event), params: {
        stocking_event: {
          batch_stocking_id: batch_stocking.id,
          occurred_on: Date.current,
          quantity: 250
        }
      }

      expect(response).to redirect_to(mortality_events_path(batch_stocking_id: batch_stocking.id))
      expect(event.reload.quantity).to eq(250)
      expect(batch_stocking.reload.current_quantity).to eq(750)
      expect(batch.reload.current_quantity).to eq(750)
      expect(batch_stocking.current_biomass_kg.to_f).to eq(3.75) # 750 * 5g / 1000
    end

    it "removes the mortality event and restores the full batch balance" do
      event

      expect do
        delete mortality_event_path(event)
      end.to change { batch_stocking.stocking_events.where(event_type: "mortality").count }.by(-1)

      expect(response).to redirect_to(mortality_events_path(batch_stocking_id: batch_stocking.id))
      expect(batch_stocking.reload).to have_attributes(current_quantity: 1000, current_biomass_kg: 5.0)
      expect(batch.reload).to have_attributes(current_quantity: 1000, current_biomass_kg: 5.0)
    end
  end
end
