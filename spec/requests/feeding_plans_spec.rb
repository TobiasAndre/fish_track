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
    batch
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

    it "asks the user to pick the unit, the batch and the pond before showing the plan" do
      batch = stock(pond, biomass_kg: 6_900, quantity: 900_000)

      get feeding_plans_path

      expect(response.body).not_to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Selecione a unidade, o lote e o tanque")

      get feeding_plans_path, params: { unit_id: unit.id }

      expect(response.body).not_to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Selecione a unidade, o lote e o tanque")

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id }

      expect(response.body).not_to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Selecione a unidade, o lote e o tanque")
    end

    it "renders the tank row with quantity, average weight, biomass and the computed ration once the unit, batch and pond are selected" do
      batch = stock(pond, biomass_kg: 6_900, quantity: 900_000) # avg 7,67 g -> faixa 3-9,9

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id, pond_id: pond.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Qtde. peixes")
      expect(response.body).to include("Tanque 4")
      expect(response.body).to include("900.000") # quantidade de peixes
      expect(response.body).to include("6.900")   # biomassa (kg)
      expect(response.body).to include("7,67")    # peso médio (g)
      expect(response.body).to include("414")     # 6900 kg * 6% = 414 kg
    end

    it "renders one column per registered temperature range, dynamically" do
      batch = stock(pond, biomass_kg: 6_900, quantity: 900_000)
      other = create(:feeding_temperature_range, temperature_from: 30, temperature_to: 31)

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id, pond_id: pond.id }

      expect(response.body).to include("24–26°C")
      expect(response.body).to include("30–31°C")

      other.destroy
      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id, pond_id: pond.id }
      expect(response.body).to include("24–26°C")
      expect(response.body).not_to include("30–31°C")
    end

    it "shows an unavailable marker (not zero) when there is no rate for a weight/temperature cell" do
      pond_no_rate = create(:pond, unit: unit, name: "Tanque 9")
      create(:feeding_weight_range, weight_from: 100, weight_to: 199.9) # faixa sem strategy items
      batch = stock(pond_no_rate, biomass_kg: 15_000, quantity: 100_000) # avg 150 g

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id, pond_id: pond_no_rate.id }

      row = Nokogiri::HTML(response.body).css("tr").find { |tr| tr.text.include?("Tanque 9") }
      temp_cell = row.css("td").last
      expect(temp_cell.text.strip).to eq("—")
      expect(temp_cell.text).not_to include("0")
    end

    it "only lists batches with active stockings in the selected unit in the batch dropdown" do
      other_unit = create(:unit, name: "Experimental")
      other_pond = create(:pond, unit: other_unit, name: "Tanque X")
      stock(pond, biomass_kg: 6_900, quantity: 900_000)
      stock(other_pond, biomass_kg: 1_000, quantity: 50_000)

      get feeding_plans_path, params: { unit_id: unit.id }

      options = Nokogiri::HTML(response.body).css("select#batch_id option").map(&:text)
      expect(options.join).to include(pond.batches.first.name)
      expect(options.join).not_to include(other_pond.batches.first.name)
    end

    it "only lists ponds stocked with the selected batch in the pond dropdown" do
      other_pond = create(:pond, unit: unit, name: "Tanque X")
      batch = stock(pond, biomass_kg: 6_900, quantity: 900_000)
      stock(other_pond, biomass_kg: 1_000, quantity: 50_000)

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id }

      options = Nokogiri::HTML(response.body).css("select#pond_id option").map(&:text)
      expect(options).to include("Tanque 4")
      expect(options).not_to include("Tanque X")
    end

    it "ignores a pond_id that isn't stocked with the selected batch" do
      other_pond = create(:pond, unit: unit, name: "Tanque X")
      batch = stock(pond, biomass_kg: 6_900, quantity: 900_000)

      get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id, pond_id: other_pond.id }

      expect(response.body).not_to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Selecione a unidade, o lote e o tanque")
    end
  end

  describe "PATCH /feeding_plans/calibrations" do
    it "stores the calibration sample on the pond and feeds the time table" do
      batch = stock(pond, biomass_kg: 6_000, quantity: 800_000)

      patch calibrations_feeding_plans_path, params: {
        feeding_table_id: feeding_table.id,
        unit_id: unit.id,
        batch_id: batch.id,
        pond_id: pond.id,
        calibrations: { pond.id.to_s => { feed_sample_kg: "650", feed_sample_seconds: "964" } }
      }

      expect(response).to redirect_to(
        feeding_plans_path(feeding_table_id: feeding_table.id, unit_id: unit.id, batch_id: batch.id, pond_id: pond.id)
      )
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
