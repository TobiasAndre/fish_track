require "rails_helper"

# Biometria em campo (offline): a tela que abre sem internet, os dados dos
# tanques que ficam no aparelho e o envio do que foi lançado offline.
RSpec.describe "Field (offline) biometry", type: :request do
  let(:user) { create(:user, name: "Joana Campo") }
  let(:company) { create(:company, name: "Piscicultura Azul", tenant_name: "public") }
  let(:unit) { create(:unit, name: "Sede") }
  let(:pond) { create(:pond, unit: unit, name: "Tanque 4") }
  let(:batch) { create(:batch, pond: pond, name: "L-07", stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  # Criar o lote já gera a biometria inicial: let! para isso não cair dentro dos blocos medidos.
  let!(:batch_stocking) { batch.batch_stockings.first }

  # O login real grava a empresa na sessão (o sign_in do Devise não passa pelo seletor).
  def log_in(role: "owner", matrix: nil)
    profile = matrix && create(:access_profile, permission_matrix: matrix.merge("__submitted" => "1"))
    create(:membership, user: user, company: company, role: role, access_profile_id: profile&.id)
    post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }
  end

  def csrf_token
    get offline_data_biometry_events_path, headers: { "Accept" => "application/json" }
    response.parsed_body["csrf_token"]
  end

  def sync(entries, token: csrf_token)
    post sync_biometry_events_path, params: { entries: entries }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json", "X-CSRF-Token" => token }
  end

  def entry(**attrs)
    {
      uuid: SecureRandom.uuid, tenant: "public", created_at: Time.current.iso8601, batch_stocking_id: batch_stocking.id,
      occurred_on: "2026-10-05", volume: "1000", quantity: "50", total_weight_kg: "12.5", feed_kg: "", notes: "Em campo"
    }.merge(attrs)
  end

  describe "GET /biometry_events/offline" do
    it "is just the screen: no company or user data and no form token, so it can be kept on the device" do
      log_in
      batch_stocking

      get offline_biometry_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Biometria em campo", 'data-controller="field-biometry"')
      expect(response.body).not_to include("Joana Campo", user.email, "Piscicultura Azul", "Tanque 4", "csrf-token", "authenticity_token")
    end

    it "requires sign in" do
      get offline_biometry_events_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /biometry_events/offline_data" do
    it "returns the active tanks with the current stock and the last biometry, plus a fresh token" do
      log_in
      create(:stocking_event, :biometrics, batch_stocking: batch_stocking, occurred_on: Date.current,
        volume: 1000, quantity: 50, total_weight_kg: 10)
      closed = create(:batch, pond: create(:pond, unit: unit, name: "Tanque 9"), status: "closed", stocking_quantity: 10, stocking_avg_weight_g: 5.0)

      get offline_data_biometry_events_path, headers: { "Accept" => "application/json" }

      data = response.parsed_body
      expect(data).to include("tenant" => "public", "company_name" => "Piscicultura Azul")
      expect(data["user"]).to include("id" => user.id, "name" => "Joana Campo")
      expect(data["csrf_token"]).to be_present
      expect(data["batch_stockings"].map { |tank| tank["id"] }).to eq([batch_stocking.id])
      expect(data["batch_stockings"].first).to include("unit" => "Sede", "pond" => "Tanque 4", "batch" => "L-07", "current_quantity" => 1000)
      expect(data["batch_stockings"].first["last_biometry"]).to include("occurred_on" => Date.current.iso8601, "avg_weight_g" => 200.0, "biomass" => 200.0)
      expect(data["batch_stockings"].map { |tank| tank["id"] }).not_to include(closed.batch_stockings.first.id)
    end

    it "answers 401 to an expired session, so the device keeps the entries and asks to sign in" do
      get offline_data_biometry_events_path, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /biometry_events/sync" do
    before { log_in }

    it "records the biometries, calculating the derived fields like the regular form" do
      first = entry(occurred_on: "2026-10-01", quantity: "50", total_weight_kg: "10")
      second = entry(occurred_on: "2026-10-05", quantity: "50", total_weight_kg: "12.5", feed_kg: "40")

      expect { sync([second, first]) }.to change { StockingEvent.where(event_type: "biometrics").count }.by(2)

      results = response.parsed_body["results"]
      expect(results.map { |result| result["status"] }).to eq(%w[created created])

      later = StockingEvent.find_by!(client_uuid: second[:uuid])
      expect(later).to have_attributes(occurred_on: Date.new(2026, 10, 5), volume: 1000, quantity: 50, notes: "Em campo")
      expect(later.avg_weight_g).to eq(250)
      expect(later.biomass).to eq(250)
      expect(later.weight_gain_kg).to eq(50) # em relação à biometria de 01/10, enviada no mesmo lote
      expect(later.gpd).to eq(12.5)
      expect(later.feed_conversion).to eq(0.8)
    end

    it "never records the same biometry twice when it is sent again" do
      biometry = entry

      sync([biometry])
      expect { sync([biometry]) }.not_to change(StockingEvent, :count)

      expect(response.parsed_body["results"].first).to include("uuid" => biometry[:uuid], "status" => "duplicate")
    end

    it "reports the validation errors of each biometry and keeps going with the others" do
      bad = entry(quantity: "")
      good = entry

      expect { sync([bad, good]) }.to change(StockingEvent, :count).by(1)

      results = response.parsed_body["results"].index_by { |result| result["uuid"] }
      expect(results[bad[:uuid]]["status"]).to eq("error")
      expect(results[bad[:uuid]]["errors"]).to be_present
      expect(results[good[:uuid]]["status"]).to eq("created")
    end

    it "refuses a biometry launched in another company" do
      biometry = entry(tenant: "outra_empresa")

      expect { sync([biometry]) }.not_to change(StockingEvent, :count)

      expect(response.parsed_body["results"].first).to include("status" => "error")
      expect(response.parsed_body["results"].first["errors"].first).to include("outra_empresa")
    end

    it "refuses an unknown tank" do
      unknown = entry(batch_stocking_id: 0)

      expect { sync([unknown]) }.not_to change(StockingEvent, :count)

      expect(response.parsed_body["results"].first["errors"].first).to include("Tanque não encontrado")
    end

    it "refuses a biometry for a batch closed after the tanks were downloaded" do
      batch.update!(status: "closed")
      biometry = entry

      expect { sync([biometry]) }.not_to change(StockingEvent, :count)

      expect(response.parsed_body["results"].first["errors"].first).to include("L-07 foi encerrado")
    end

    it "requires the form token" do
      ActionController::Base.allow_forgery_protection = true
      biometry = entry

      expect { sync([biometry], token: "wrong") }.not_to change(StockingEvent, :count)
      expect(response).to have_http_status(:unprocessable_content)

      expect { sync([biometry]) }.to change(StockingEvent, :count).by(1)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  it "does not let a read-only profile send biometries" do
    log_in(role: "member", matrix: { "dashboard" => %w[read], "biometry_events" => %w[read] })
    biometry = entry

    expect { sync([biometry]) }.not_to change(StockingEvent, :count)
    expect(response).to have_http_status(:forbidden)
  end

  describe "entry points" do
    it "links the biometry page to the field screen with a full (non-Turbo) visit" do
      log_in

      get biometry_events_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{offline_biometry_events_path}']")
      expect(link).to be_present
      expect(link["data-turbo"]).to eq("false")
    end

    it "clears the downloaded tanks from the device on the sign-in page" do
      get new_user_session_path

      expect(Nokogiri::HTML(response.body).at_css("[data-controller~='field-biometry-cleanup']")).to be_present
    end

    it "offers the field screen on the no-connection page" do
      expect(Rails.public_path.join("offline.html").read).to include('href="/biometry_events/offline"')
    end
  end
end
