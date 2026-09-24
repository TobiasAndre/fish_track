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

  def pond_rows(doc)
    doc.css("h2:contains('Trato (Kg)')").first.ancestors("div").first.css("tbody tr").map { |tr| tr.at_css("td").text.strip }
  end

  def time_rows(doc)
    doc.css("h2:contains('Tempo (min)')").first.ancestors("div").first.css("tbody tr").map { |tr| tr.at_css("td").text.strip }
  end

  describe "GET /feeding_plans" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_plans_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "asks for the unit before showing the tables" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000)

      get feeding_plans_path

      expect(response.body).not_to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Selecione a unidade acima")
    end

    it "shows the trato (kg) and the time (min) tables for every tank of the unit once it is selected" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000)
      stock(create(:pond, unit: unit, name: "Tanque 7"), biomass_kg: 3_000, quantity: 400_000)

      get feeding_plans_path, params: { unit_id: unit.id }

      doc = Nokogiri::HTML(response.body)
      expect(pond_rows(doc)).to eq(["Tanque 4", "Tanque 7"])
      expect(time_rows(doc)).to eq(["Tanque 4", "Tanque 7"])
    end

    it "renders the tank row with quantity, average weight, biomass and the computed ration" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000) # avg 7,67 g -> faixa 3-9,9

      get feeding_plans_path, params: { unit_id: unit.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Trato (Kg) por temperatura")
      expect(response.body).to include("Tempo (min) por temperatura")
      expect(response.body).to include("Qtde. peixes")
      expect(response.body).to include("900.000") # quantidade de peixes
      expect(response.body).to include("6.900")   # biomassa (kg)
      expect(response.body).to include("7,67")    # peso médio (g)
      expect(response.body).to include("414")     # 6900 kg * 6% = 414 kg
    end

    describe "tank selection" do
      let!(:pond_7) { create(:pond, unit: unit, name: "Tanque 7", order_number: 2) }
      let!(:pond_9) { create(:pond, unit: unit, name: "Tanque 9", order_number: 3) }
      let!(:pond_11) { create(:pond, unit: unit, name: "Tanque 11", order_number: 4) }
      let!(:batch) { stock(pond, biomass_kg: 6_900, quantity: 900_000) }

      before do
        stock(pond_7, biomass_kg: 3_000, quantity: 400_000)
        stock(pond_9, biomass_kg: 2_000, quantity: 300_000)
        stock(pond_11, biomass_kg: 1_000, quantity: 100_000)
        pond.update!(order_number: 1)
      end

      it "reduces both tables to the checked tanks (e.g. 4, 7 and 9)" do
        get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond.id, pond_7.id, pond_9.id] }

        doc = Nokogiri::HTML(response.body)
        expect(pond_rows(doc)).to eq(["Tanque 4", "Tanque 7", "Tanque 9"])
        expect(time_rows(doc)).to eq(["Tanque 4", "Tanque 7", "Tanque 9"])
        expect(response.body).not_to include("Tanque 11</td>")
      end

      it "lists every tank as a checkbox and marks the selected ones" do
        get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond_7.id] }

        boxes = Nokogiri::HTML(response.body).css("input[type=checkbox][name='pond_ids[]']")
        expect(boxes.size).to eq(4)
        expect(boxes.select { |b| b["checked"] }.map { |b| b["value"] }).to eq([pond_7.id.to_s])
      end

      it "shows all tanks again when none is checked" do
        get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [""] }

        expect(pond_rows(Nokogiri::HTML(response.body)).size).to eq(4)
      end

      it "ignores tanks that don't belong to the selected unit" do
        foreign = create(:pond, unit: create(:unit, name: "Experimental"), name: "Tanque X")

        get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond_7.id, foreign.id] }

        expect(pond_rows(Nokogiri::HTML(response.body))).to eq(["Tanque 7"])
        expect(response.body).not_to include("Tanque X")
      end

      it "offers a link back to all tanks only while a selection is active" do
        get feeding_plans_path, params: { unit_id: unit.id }
        expect(response.body).not_to include("Todos os tanques")

        get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond_7.id] }
        expect(response.body).to include("Todos os tanques")
      end

      it "narrows the tank list and the ration to the selected lote" do
        other_batch = create(:batch, pond: pond_7, stocking_quantity: 100, stocking_avg_weight_g: 7.0)
        other_batch.batch_stockings.first.update_columns(current_biomass_kg: 500, current_quantity: 100)

        get feeding_plans_path, params: { unit_id: unit.id, batch_id: batch.id }

        doc = Nokogiri::HTML(response.body)
        expect(pond_rows(doc)).to eq(["Tanque 4"])
        expect(doc.css("input[type=checkbox][name='pond_ids[]']").map { |b| b["value"] }).to eq([pond.id.to_s])
      end
    end

    it "sums every active lote of a tank when no lote is selected" do
      stock(pond, biomass_kg: 3_000, quantity: 400_000)
      stock(pond, biomass_kg: 900, quantity: 100_000)

      get feeding_plans_path, params: { unit_id: unit.id }

      expect(response.body).to include("500.000") # 400.000 + 100.000 peixes
      expect(response.body).to include("3.900")   # 3.000 + 900 kg
    end

    it "renders one column per registered temperature range, dynamically" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000)
      other = create(:feeding_temperature_range, temperature_from: 30, temperature_to: 31)

      get feeding_plans_path, params: { unit_id: unit.id }

      expect(response.body).to include("24–26°C")
      expect(response.body).to include("30–31°C")

      other.destroy
      get feeding_plans_path, params: { unit_id: unit.id }
      expect(response.body).to include("24–26°C")
      expect(response.body).not_to include("30–31°C")
    end

    it "shows an unavailable marker (not zero) when there is no rate for a weight/temperature cell" do
      pond_no_rate = create(:pond, unit: unit, name: "Tanque 9")
      create(:feeding_weight_range, weight_from: 100, weight_to: 199.9) # faixa sem strategy items
      stock(pond_no_rate, biomass_kg: 15_000, quantity: 100_000) # avg 150 g

      get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond_no_rate.id] }

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
      expect(options).to include("Todos os lotes")
      expect(options.join).to include(pond.batches.first.name)
      expect(options.join).not_to include(other_pond.batches.first.name)
    end

    it "tells when the unit has no tank" do
      get feeding_plans_path, params: { unit_id: create(:unit, name: "Vazia").id }

      expect(response.body).to include("Nenhum tanque encontrado")
    end
  end

  describe "Turbo Frame (only the content reloads when a filter changes)" do
    before { stock(pond, biomass_kg: 6_900, quantity: 900_000) }

    it "wraps the filters and the tables in a frame that advances the URL" do
      get feeding_plans_path, params: { unit_id: unit.id }

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame#feeding_plan")
      expect(frame["data-turbo-action"]).to eq("advance")
      expect(frame.at_css("form select#unit_id")).to be_present
      expect(frame.text).to include("Trato (Kg) por temperatura", "Tempo (min) por temperatura")
    end

    it "keeps the page title and heading outside the frame, so they aren't re-rendered" do
      get feeding_plans_path, params: { unit_id: unit.id }

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("h1").ancestors("turbo-frame")).to be_empty
    end

    it "answers a frame request with just the frame, without the app layout" do
      get feeding_plans_path, params: { unit_id: unit.id, pond_ids: [pond.id] }, headers: { "Turbo-Frame" => "feeding_plan" }

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#feeding_plan")).to be_present
      expect(response.body).not_to include("Fish Track</span>") # sidebar/topbar
      expect(doc.css("nav")).to be_empty
    end

    it "sends the calibration form and the link to register a table out of the frame (full visit)" do
      FeedingTable.destroy_all

      get feeding_plans_path, params: { unit_id: unit.id }

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("form[action='#{calibrations_feeding_plans_path}']")["data-turbo-frame"]).to eq("_top")
      expect(doc.at_css("a[href='#{new_feeding_table_path}']")["data-turbo-frame"]).to eq("_top")
    end
  end

  describe "PATCH /feeding_plans/calibrations" do
    it "stores the calibration sample on the pond and feeds the time table" do
      batch = stock(pond, biomass_kg: 6_000, quantity: 800_000)

      patch calibrations_feeding_plans_path, params: {
        feeding_table_id: feeding_table.id,
        unit_id: unit.id,
        batch_id: batch.id,
        pond_ids: [pond.id],
        calibrations: { pond.id.to_s => { feed_sample_kg: "650", feed_sample_seconds: "964" } }
      }

      expect(response).to redirect_to(
        feeding_plans_path(feeding_table_id: feeding_table.id, unit_id: unit.id, batch_id: batch.id, pond_ids: [pond.id])
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
