require "rails_helper"

RSpec.describe "WaterQualityReadings", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:unit) { create(:unit, name: "Sede") }
  let!(:pond_4) { create(:pond, unit: unit, name: "Tanque 4", order_number: 1) }
  let!(:pond_7) { create(:pond, unit: unit, name: "Tanque 7", order_number: 2) }

  before { sign_in user }

  def doc
    Nokogiri::HTML(response.body)
  end

  def frame
    doc.at_css("turbo-frame#water_quality")
  end

  def create_params(**overrides)
    { water_quality_reading: { pond_id: pond_4.id, measured_at: Time.current.strftime("%Y-%m-%dT%H:%M"), ph: "7,8".tr(",", "."),
                               nitrite: "0.05", ammonia: "0.2", alkalinity: "110", salinity: "3.5", notes: "Manhã" }.merge(overrides) }
  end

  describe "GET /water_quality_readings" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get water_quality_readings_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the form with a field for each parameter and a tank select" do
      get water_quality_readings_path

      expect(response).to have_http_status(:ok)
      form = frame.at_css("form[action='#{water_quality_readings_path}']")
      %w[ph nitrite ammonia alkalinity salinity].each do |parameter|
        expect(form.at_css("input[name='water_quality_reading[#{parameter}]']")).to be_present
      end
      expect(form.css("select#water_quality_reading_pond_id option").map(&:text)).to include("Sede - Tanque 4", "Sede - Tanque 7")
      expect(form.at_css("input[type=datetime-local]")).to be_present
    end

    it "lists every tank in the latest-analysis table, showing the last reading of each and a message for tanks without one" do
      create(:water_quality_reading, pond: pond_4, measured_at: 3.days.ago, ph: 6.9)
      create(:water_quality_reading, pond: pond_4, measured_at: 1.day.ago.change(hour: 9, min: 30), ph: 7.6, ammonia: 0.25, nitrite: nil)

      get water_quality_readings_path

      table = doc.css("h2").find { |h| h.text.include?("Última análise") }.ancestors("div.rounded-xl").first
      rows = table.css("tbody tr").map { |tr| tr.text.gsub(/\s+/, " ").strip }
      expect(rows.size).to eq(2)
      expect(rows.first).to include("Sede - Tanque 4", "09:30", "7,60", "0,250")
      expect(rows.first).not_to include("6,90")
      expect(rows.last).to include("Sede - Tanque 7", "Sem análise lançada.")
    end

    it "shows a dash for a parameter that wasn't measured in the last reading" do
      create(:water_quality_reading, pond: pond_4, ph: nil, salinity: 2.5)

      get water_quality_readings_path

      row = doc.css("tbody tr").find { |tr| tr.text.include?("Tanque 4") }
      cells = row.css("td").map { |td| td.text.strip }
      expect(cells).to include("—", "2,50")
    end

    it "defaults the chart to the tank with the most recent reading and to the last 30 days" do
      create(:water_quality_reading, pond: pond_7, measured_at: 2.days.ago)
      create(:water_quality_reading, pond: pond_4, measured_at: 6.days.ago)

      get water_quality_readings_path

      expect(doc.at_css("select#pond_id option[selected]").text).to eq("Sede - Tanque 7")
      expect(doc.at_css("input#from")["value"]).to eq((Date.current - 29).iso8601)
      expect(doc.at_css("input#to")["value"]).to eq(Date.current.iso8601)
      expect(frame.text).to include("Histórico — Sede - Tanque 7")
    end

    it "asks for a tank when there is no reading yet" do
      get water_quality_readings_path

      expect(response.body).to include("Selecione um tanque para ver o gráfico do período.")
      expect(doc.css("[data-controller=chart]")).to be_empty
    end

    it "renders one chart per parameter with the series of the selected tank and period, oldest first" do
      create(:water_quality_reading, pond: pond_4, measured_at: Time.zone.parse("2026-09-10 08:00"), ph: 7.1, ammonia: 0.1)
      create(:water_quality_reading, pond: pond_4, measured_at: Time.zone.parse("2026-09-12 08:00"), ph: 7.6, ammonia: nil)
      create(:water_quality_reading, pond: pond_4, measured_at: Time.zone.parse("2026-08-01 08:00"), ph: 5.0) # fora do período
      create(:water_quality_reading, pond: pond_7, measured_at: Time.zone.parse("2026-09-11 08:00"), ph: 9.9) # outro tanque

      get water_quality_readings_path(pond_id: pond_4.id, from: "2026-09-01", to: "2026-09-30")

      ph_chart = doc.at_css("#water-chart-ph")
      series = JSON.parse(ph_chart["data-chart-series-value"])
      expect(series.map(&:last)).to eq([7.1, 7.6])
      expect(series.first.first).to start_with("2026-09-10T08:00:00")
      expect(ph_chart["data-chart-label-value"]).to eq("pH")
      expect(JSON.parse(doc.at_css("#water-chart-ammonia")["data-chart-series-value"]).map(&:last)).to eq([0.1])
      expect(frame.text).to include("Sem lançamentos de Nitrito no período.")
      expect(doc.css("[data-controller=chart]").size).to eq(2)
    end

    it "says so when the tank has no reading in the period" do
      create(:water_quality_reading, pond: pond_4, measured_at: Time.zone.parse("2026-01-10 08:00"))

      get water_quality_readings_path(pond_id: pond_4.id, from: "2026-09-01", to: "2026-09-30")

      expect(response.body).to include("Nenhuma análise de Sede - Tanque 4 entre")
      expect(doc.css("[data-controller=chart]")).to be_empty
    end

    it "swaps the dates when the period is reversed and ignores invalid dates" do
      get water_quality_readings_path(from: "2026-09-30", to: "2026-09-01")
      expect(doc.at_css("input#from")["value"]).to eq("2026-09-01")
      expect(doc.at_css("input#to")["value"]).to eq("2026-09-30")

      get water_quality_readings_path(from: "not-a-date", to: "also-bad")
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("input#to")["value"]).to eq(Date.current.iso8601)
    end

    it "lists the period's readings newest first with edit and delete actions" do
      create(:water_quality_reading, pond: pond_4, measured_at: 3.days.ago.change(hour: 8), ph: 7.0, notes: "Antiga")
      create(:water_quality_reading, pond: pond_4, measured_at: 1.day.ago.change(hour: 8), ph: 7.9, notes: "Recente")

      get water_quality_readings_path(pond_id: pond_4.id)

      rows = frame.css("table").last.css("tbody tr")
      expect(rows.map { |r| r.text }.join).to include("Recente", "Antiga")
      expect(rows.first.text).to include("Recente")
      expect(rows.first.at_css("a[title=Editar]")).to be_present
      expect(rows.first.at_css("a[data-turbo-method=delete]")["data-turbo-action"]).to eq("replace")
    end
  end

  describe "POST /water_quality_readings" do
    it "saves the analysis and shows that tank's history" do
      expect { post water_quality_readings_path, params: create_params }.to change(WaterQualityReading, :count).by(1)

      reading = WaterQualityReading.last
      expect(reading).to have_attributes(pond_id: pond_4.id, ph: 7.8.to_d, nitrite: 0.05.to_d, ammonia: 0.2.to_d, alkalinity: 110.to_d, salinity: 3.5.to_d, notes: "Manhã")
      expect(response).to redirect_to(water_quality_readings_path(pond_id: pond_4.id))
    end

    it "keeps the chosen period after saving" do
      post water_quality_readings_path, params: create_params.merge(from: "2026-09-01", to: "2026-09-30")

      expect(response).to redirect_to(water_quality_readings_path(from: "2026-09-01", to: "2026-09-30", pond_id: pond_4.id))
    end

    it "accepts a reading with a single parameter" do
      expect do
        post water_quality_readings_path, params: create_params(nitrite: "", ammonia: "", alkalinity: "", salinity: "", ph: "6.9")
      end.to change(WaterQualityReading, :count).by(1)
    end

    it "shows the errors in the form when no parameter is informed" do
      expect do
        post water_quality_readings_path, params: create_params(ph: "", nitrite: "", ammonia: "", alkalinity: "", salinity: "")
      end.not_to change(WaterQualityReading, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(frame.text).to include("Não foi possível salvar", "pelo menos um parâmetro")
    end

    it "rejects an out-of-range pH and a missing tank" do
      post water_quality_readings_path, params: create_params(ph: "15")
      expect(response).to have_http_status(:unprocessable_content)

      post water_quality_readings_path, params: create_params(pond_id: "")
      expect(response).to have_http_status(:unprocessable_content)
      expect(WaterQualityReading.count).to eq(0)
    end

    it "keeps what was typed when there is an error" do
      post water_quality_readings_path, params: create_params(ph: "15", ammonia: "0.4")

      expect(frame.at_css("input[name='water_quality_reading[ammonia]']")["value"]).to eq("0.4")
    end
  end

  describe "editing and deleting" do
    let!(:reading) { create(:water_quality_reading, pond: pond_4, measured_at: 1.day.ago.change(hour: 8, min: 0), ph: 7.0) }

    it "opens the reading in the form" do
      get edit_water_quality_reading_path(reading)

      expect(response).to have_http_status(:ok)
      expect(frame.text).to include("Editar análise")
      expect(frame.at_css("form[action='#{water_quality_reading_path(reading)}']")).to be_present
      expect(frame.at_css("input[name='water_quality_reading[ph]']")["value"]).to eq("7.0")
      expect(frame.text).to include("Histórico — Sede - Tanque 4")
    end

    it "updates the reading" do
      patch water_quality_reading_path(reading), params: { water_quality_reading: { ph: "8.1" } }

      expect(reading.reload.ph).to eq(8.1.to_d)
      expect(response).to redirect_to(water_quality_readings_path(pond_id: pond_4.id))
    end

    it "shows the errors when the update is invalid" do
      patch water_quality_reading_path(reading), params: { water_quality_reading: { ph: "20" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(reading.reload.ph).to eq(7.0.to_d)
    end

    it "deletes the reading and keeps the tank and period" do
      expect { delete water_quality_reading_path(reading, from: "2026-09-01", to: "2026-09-30") }.to change(WaterQualityReading, :count).by(-1)

      expect(response).to redirect_to(water_quality_readings_path(from: "2026-09-01", to: "2026-09-30", pond_id: pond_4.id))
    end
  end

  describe "Turbo Frame (only the affected area reloads)" do
    it "wraps the form, latest table, charts and history in one frame that advances the URL, keeping the heading outside" do
      create(:water_quality_reading, pond: pond_4)

      get water_quality_readings_path

      expect(frame["data-turbo-action"]).to eq("advance")
      expect(frame.at_css("form[action='#{water_quality_readings_path}']")["data-turbo-action"]).to eq("replace")
      expect(frame.at_css("select#pond_id")).to be_present
      expect(doc.at_css("h1").ancestors("turbo-frame")).to be_empty
    end

    it "renders the flash toast inside the frame, once, after saving" do
      post water_quality_readings_path, params: create_params
      follow_redirect!

      toasts = doc.css('[data-controller="flash"]')
      expect(toasts.size).to eq(1)
      expect(toasts.sole["data-flash-message-value"]).to eq("Análise lançada com sucesso.")
      expect(toasts.sole.ancestors("turbo-frame").map { |f| f["id"] }).to include("water_quality")
    end

    it "answers the frame request after saving with just the frame, the new analysis and the toast" do
      post water_quality_readings_path, params: create_params, headers: { "Turbo-Frame" => "water_quality" }
      follow_redirect!(headers: { "Turbo-Frame" => "water_quality" })

      expect(doc.css("nav")).to be_empty
      expect(doc.css('[data-controller="flash"]').size).to eq(1)
      expect(doc.text).to include("7,80")
      expect(doc.css("[data-controller=chart]")).not_to be_empty
    end
  end
end
