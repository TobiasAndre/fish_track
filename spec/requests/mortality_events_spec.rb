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

  describe "Turbo Frames (only the affected area reloads)" do
    def frame(id)
      Nokogiri::HTML(response.body).at_css("turbo-frame##{id}")
    end

    def new_event(**attrs)
      create(:stocking_event, event_type: "mortality", batch_stocking: batch_stocking, occurred_on: Date.current - 2, quantity: 10, **attrs)
    end

    def create_params(**overrides)
      { stocking_event: { batch_stocking_id: batch_stocking.id, occurred_on: Date.current, quantity: 5 }.merge(overrides) }
    end

    it "wraps the summary, form and history of a batch stocking in one frame that advances the URL, keeping the back link outside" do
      get mortality_events_path(batch_stocking_id: batch_stocking.id)

      workspace = frame("mortality_workspace")
      expect(workspace["data-turbo-action"]).to eq("advance")
      expect(workspace.at_css("form[action='#{mortality_events_path}']")).to be_present
      expect(workspace.text).to include("Novo lançamento", "Histórico")
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{mortality_events_path}']").ancestors("turbo-frame")).to be_empty
    end

    it "makes saving and deleting replace the history entry instead of stacking the same URL" do
      new_event

      get mortality_events_path(batch_stocking_id: batch_stocking.id)

      workspace = frame("mortality_workspace")
      expect(workspace.at_css("form[action='#{mortality_events_path}']")["data-turbo-action"]).to eq("replace")
      expect(workspace.css("a[data-turbo-method=delete]").map { |a| a["data-turbo-action"] }.uniq).to eq(["replace"])
    end

    it "renders the flash toast inside the frame, once, after a save" do
      post mortality_events_path, params: create_params
      follow_redirect!

      toasts = Nokogiri::HTML(response.body).css('[data-controller="flash"]')
      expect(toasts.size).to eq(1)
      expect(toasts.sole["data-flash-message-value"]).to eq("Mortalidade lançada com sucesso.")
      expect(toasts.sole.ancestors("turbo-frame").map { |f| f["id"] }).to include("mortality_workspace")
    end

    it "answers the frame request after a save with just the frame and the toast, without the app layout" do
      post mortality_events_path, params: create_params, headers: { "Turbo-Frame" => "mortality_workspace" }
      follow_redirect!(headers: { "Turbo-Frame" => "mortality_workspace" }) if response.redirect?

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#mortality_workspace")).to be_present
      expect(doc.css("nav")).to be_empty
      expect(doc.css('[data-controller="flash"]').size).to eq(1)
      expect(doc.css("tbody tr").size).to be >= 1
    end

    it "re-renders the form with the errors inside the frame on a validation failure" do
      post mortality_events_path, params: create_params(occurred_on: nil), headers: { "Turbo-Frame" => "mortality_workspace" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(frame("mortality_workspace").text).to include("Não foi possível salvar")
    end

    it "opens an edit inside the frame" do
      event = new_event

      get edit_mortality_event_path(event), headers: { "Turbo-Frame" => "mortality_workspace" }

      expect(frame("mortality_workspace").text).to include("Editar")
    end

    it "keeps the overview filters and list in their own frame and sends the actions to a full visit" do
      new_event

      get mortality_events_path

      overview = frame("mortality_overview")
      expect(overview["data-turbo-action"]).to eq("advance")
      expect(overview.at_css("select#unit_id")).to be_present
      expect(overview.at_css("a[href='#{mortality_events_path(batch_stocking_id: batch_stocking.id)}']")["data-turbo-frame"]).to eq("_top")
      expect(overview.css("a[title=Editar]").map { |a| a["data-turbo-frame"] }.uniq).to eq(["_top"])
      expect(overview.css("a[data-turbo-method=delete]").map { |a| a["data-turbo-frame"] }.uniq).to eq(["_top"])
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
