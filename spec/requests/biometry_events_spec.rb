require "rails_helper"

RSpec.describe "BiometryEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }

  before { sign_in user }

  describe "GET /biometry_events" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get biometry_events_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists every active batch stocking with its history when no batch is selected" do
      batch_stocking

      get biometry_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(batch_stocking.display_name)
    end

    it "filters the active batches by unit" do
      other_unit = create(:unit)
      other_pond = create(:pond, unit: other_unit)
      other_batch = create(:batch, pond: other_pond)
      batch_stocking # ensure the primary batch_stocking exists too

      get biometry_events_path, params: { unit_id: other_unit.id }

      expect(response.body).to include(other_batch.batch_stockings.first.display_name)
      expect(response.body).not_to include(batch_stocking.display_name)
    end

    it "shows the form and history for the selected batch stocking" do
      get biometry_events_path(batch_stocking_id: batch_stocking.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novo lançamento")
      expect(response.body).to include("Histórico")
    end
  end

  describe "POST /biometry_events" do
    it "creates a biometry stocking event with valid params" do
      expect do
        post biometry_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            volume: 950,
            quantity: 950,
            total_weight_kg: 6.0
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "biometrics").count }.by(1)

      expect(response).to redirect_to(biometry_events_path(batch_stocking_id: batch_stocking.id))
    end

    it "re-renders the form with errors when required fields are missing" do
      expect do
        post biometry_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            volume: nil,
            quantity: nil,
            total_weight_kg: nil
          }
        }
      end.not_to change { batch_stocking.stocking_events.where(event_type: "biometrics").count }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
