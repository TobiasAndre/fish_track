require "rails_helper"

RSpec.describe "FeedingPlans", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit, name: "Sede") }
  let(:pond) { create(:pond, unit: unit, name: "Tanque 4") }

  let(:temp_range) { create(:feeding_temperature_range, temperature_from: 24, temperature_to: 26) }
  let(:weight_range) { create(:feeding_weight_range, weight_from: 3, weight_to: 9.9) }
  let(:feeding_table) { create(:feeding_table, name: "Tabela Sede") }

  def stock(pond, biomass_kg:, quantity:)
    batch = create(:batch, pond: pond, stocking_quantity: quantity, stocking_avg_weight_g: 7.0)
    batch.batch_stockings.first.update_columns(current_biomass_kg: biomass_kg, current_quantity: quantity)
  end

  before do
    create(:feeding_strategy_item,
      feeding_table: feeding_table, feeding_weight_range: weight_range,
      feeding_temperature_range: temp_range, feeding_percentage: 6.0)
    sign_in user
  end

  describe "GET /feeding_plans" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_plans_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the feed table with the computed ration per pond" do
      stock(pond, biomass_kg: 6_000, quantity: 800_000) # avg 7,5 g -> faixa 3-9,9

      get feeding_plans_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Tempo (min) por temperatura")
      expect(response.body).to include("Tanque 4")
      expect(response.body).to include("360") # 6000 kg * 6% = 360 kg
    end

    it "filters the ponds by unit" do
      other_unit = create(:unit, name: "Experimental")
      create(:pond, unit: other_unit, name: "Tanque X")
      pond

      get feeding_plans_path, params: { unit_id: unit.id }

      expect(response.body).to include("Tanque 4")
      expect(response.body).not_to include("Tanque X")
    end
  end

  describe "PATCH /feeding_plans/calibrations" do
    it "stores the calibration sample on the pond and feeds the time table" do
      stock(pond, biomass_kg: 6_000, quantity: 800_000)

      patch calibrations_feeding_plans_path, params: {
        feeding_table_id: feeding_table.id,
        unit_id: unit.id,
        calibrations: { pond.id.to_s => { feed_sample_kg: "650", feed_sample_seconds: "964" } }
      }

      expect(response).to redirect_to(feeding_plans_path(feeding_table_id: feeding_table.id, unit_id: unit.id))
      expect(pond.reload).to have_attributes(feed_sample_kg: 650, feed_sample_seconds: 964)

      follow_redirect!
      # 360 kg * (964/650) / 60 ≈ 8,9 min
      expect(response.body).to include("8,9")
    end

    it "clears the calibration when the fields are left blank" do
      pond.update!(feed_sample_kg: 100, feed_sample_seconds: 200)

      patch calibrations_feeding_plans_path, params: {
        calibrations: { pond.id.to_s => { feed_sample_kg: "", feed_sample_seconds: "" } }
      }

      expect(pond.reload.feed_sample_kg).to be_nil
      expect(pond.reload.feed_sample_seconds).to be_nil
    end
  end
end
