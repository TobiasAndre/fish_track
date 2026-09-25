require "rails_helper"

RSpec.describe "Simulations", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:customer) { create(:customer) }

  before { sign_in user }

  describe "Turbo Frame (only the list reloads)" do
    def frame
      Nokogiri::HTML(response.body).at_css("turbo-frame#simulations")
    end

    it "wraps the filter, table and paging in a frame, keeping the New button outside" do
      create(:simulation, customer: customer)

      get simulations_path

      expect(frame["data-turbo-action"]).to eq("advance")
      expect(frame.at_css("select#customer_id")).to be_present
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{new_simulation_path}']").ancestors("turbo-frame")).to be_empty
    end

    it "sends edit/print/share out of the frame and makes delete replace the history entry" do
      simulation = create(:simulation, customer: customer)

      get simulations_path

      expect(frame.at_css("a[href='#{edit_simulation_path(simulation)}']")["data-turbo-frame"]).to eq("_top")
      expect(frame.at_css("a[href*='/print']")["data-turbo-frame"]).to eq("_top")
      expect(frame.at_css("a[data-turbo-method=delete]")["data-turbo-action"]).to eq("replace")
    end

    it "renders the flash toast inside the frame after deleting" do
      simulation = create(:simulation, customer: customer)

      delete simulation_path(simulation)
      follow_redirect!

      toasts = Nokogiri::HTML(response.body).css('[data-controller="flash"]')
      expect(toasts.size).to eq(1)
      expect(toasts.sole.ancestors("turbo-frame").map { |f| f["id"] }).to include("simulations")
    end

    it "answers a frame request with just the filtered frame" do
      other = create(:simulation, customer: create(:customer), quantity: 9_999)
      create(:simulation, customer: customer, quantity: 1_234)

      get simulations_path(customer_id: customer.id), headers: { "Turbo-Frame" => "simulations" }

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("nav")).to be_empty
      expect(response.body).to include("1.234")
      expect(response.body).not_to include("9.999")
    end
  end

  describe "GET /simulations" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get simulations_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists simulations and filters by customer" do
      other_customer = create(:customer)
      create(:simulation, customer: customer, quantity: 1_234)
      create(:simulation, customer: other_customer, quantity: 9_999)

      get simulations_path, params: { customer_id: customer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1.234")
      expect(response.body).not_to include("9.999")
    end
  end

  describe "POST /simulations" do
    it "creates a simulation and computes totals" do
      expect do
        post simulations_path, params: {
          simulation: {
            customer_id: customer.id,
            simulated_on: Date.current,
            quantity: 1000,
            avg_weight_kg: 0.5,
            price_per_kg_cents: 1_500,
            loading_count: 1
          }
        }
      end.to change(Simulation, :count).by(1)

      expect(response).to redirect_to(simulations_path)
      expect(Simulation.last.total_weight_kg.to_f).to eq(500.0)
    end

    it "does not create a simulation without a customer" do
      expect do
        post simulations_path, params: {
          simulation: {
            customer_id: nil,
            simulated_on: Date.current,
            quantity: 1000,
            avg_weight_kg: 0.5,
            loading_count: 1
          }
        }
      end.not_to change(Simulation, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /simulations/:id" do
    it "updates the simulation" do
      sim = create(:simulation, customer: customer, notes: "old")

      patch simulation_path(sim), params: { simulation: { notes: "new" } }

      expect(response).to redirect_to(simulations_path)
      expect(sim.reload.notes).to eq("new")
    end
  end

  describe "DELETE /simulations/:id" do
    it "removes the simulation" do
      sim = create(:simulation, customer: customer)

      expect do
        delete simulation_path(sim)
      end.to change(Simulation, :count).by(-1)

      expect(response).to redirect_to(simulations_path)
    end
  end
end
