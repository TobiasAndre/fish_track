require "rails_helper"

RSpec.describe "LoadingEvents", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }
  let(:batch) { create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }
  let(:customer) { create(:customer) }
  let(:payment_method) { create(:payment_method) }
  let(:supplier) { create(:supplier) }

  before { sign_in user }

  describe "GET /loading_events" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get loading_events_path

      expect(response).to have_http_status(:redirect)
    end

    it "shows a placeholder when no batch is selected" do
      get loading_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Selecione um lote")
    end

    it "shows the form and history for the selected batch stocking" do
      get loading_events_path(batch_stocking_id: batch_stocking.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novo lançamento")
    end

    it "shows a print action for each event in the history" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      get loading_events_path(batch_stocking_id: batch_stocking.id)

      expect(response.body).to include(print_loading_event_path(event, format: :pdf))
    end
  end

  describe "POST /loading_events" do
    it "creates a loading stocking event, deriving quantity from weight and avg weight" do
      expect do
        post loading_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: Date.current,
            customer_id: customer.id,
            supplier_id: supplier.id,
            payment_method_id: payment_method.id,
            total_weight_kg: 100,
            avg_weight_g: 500,
            tax_percentage: 12.5,
            loading_destination: "Tanque 3",
            gta_number: "123456",
            invoice_number: "987654"
          }
        }
      end.to change { batch_stocking.stocking_events.where(event_type: "loading").count }.by(1)

      event = batch_stocking.stocking_events.where(event_type: "loading").last

      expect(response).to redirect_to(
        loading_events_path(batch_stocking_id: batch_stocking.id, printable_event_id: event.id)
      )
      expect(event.quantity).to eq(200) # ceil((100 * 1000) / 500)
      expect(event.tax_percentage.to_f).to eq(12.5)
      expect(event.loading_destination).to eq("Tanque 3")
      expect(event.gta_number).to eq("123456")
      expect(event.invoice_number).to eq("987654")
      expect(event.supplier).to eq(supplier)
    end

    it "does not attempt to open WhatsApp when the user has no tenant selected in session" do
      # sign_in (Devise::Test helper) bypasses the real tenant-picker login flow,
      # so session[:tenant_name] is blank here -- the view must not crash on that.
      post loading_events_path, params: {
        stocking_event: {
          batch_stocking_id: batch_stocking.id,
          occurred_on: Date.current,
          customer_id: customer.id,
          payment_method_id: payment_method.id,
          total_weight_kg: 100,
          avg_weight_g: 500
        }
      }
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("wa.me")
    end

    it "auto-opens a WhatsApp link with the shareable PDF url when a tenant is selected" do
      # Devise::Test::IntegrationHelpers#sign_in bypasses the real tenant-picker
      # login flow (and its session cookie), so sign out first and authenticate
      # through the actual controller action to get a working session[:tenant_name].
      sign_out user
      company = create(:company, tenant_name: "public")
      create(:membership, user: user, company: company, role: "owner")
      post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }

      post loading_events_path, params: {
        stocking_event: {
          batch_stocking_id: batch_stocking.id,
          occurred_on: Date.current,
          customer_id: customer.id,
          payment_method_id: payment_method.id,
          total_weight_kg: 100,
          avg_weight_g: 500
        }
      }

      event = batch_stocking.stocking_events.where(event_type: "loading").last
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("window.open")
      expect(response.body).to include("https://wa.me/?text=")

      event.reload
      expect(event.share_token).to be_present
      shared_url = shared_loading_event_pdf_url(
        tenant_name: "public", id: event.id, share_token: event.share_token, format: :pdf,
        host: "www.example.com"
      )
      expect(response.body).to include(CGI.escape(shared_url))
    end

    it "does not create a loading event without an occurred_on" do
      expect do
        post loading_events_path, params: {
          stocking_event: {
            batch_stocking_id: batch_stocking.id,
            occurred_on: nil,
            total_weight_kg: 100,
            avg_weight_g: 500
          }
        }
      end.not_to change { batch_stocking.stocking_events.where(event_type: "loading").count }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /loading_events/:id/print" do
    it "renders a PDF of the loading event" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking, customer: customer)

      get print_loading_event_path(event, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "shows the origin pond and the destination tank" do
      event = create(
        :stocking_event, :loading,
        batch_stocking: batch_stocking, customer: customer,
        loading_destination: "Tanque 3"
      )

      get print_loading_event_path(event)

      expect(response.body).to include(pond.name)
      expect(response.body).to include("Tanque 3")
    end

    it "shows the supplier when present" do
      event = create(
        :stocking_event, :loading,
        batch_stocking: batch_stocking, customer: customer, supplier: supplier
      )

      get print_loading_event_path(event)

      expect(response.body).to include("Fornecedor")
      expect(response.body).to include(supplier.name)
    end
  end

  describe "GET /shared/:tenant_name/loading_events/:id/:share_token" do
    it "renders the PDF publicly, without requiring authentication" do
      sign_out user
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking, customer: customer)

      get shared_loading_event_pdf_path(tenant_name: "public", id: event.id, share_token: event.share_token, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not found with an invalid share_token" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking, customer: customer)

      get shared_loading_event_pdf_path(tenant_name: "public", id: event.id, share_token: "wrong-token", format: :pdf)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /loading_events/:id/edit" do
    it "renders the form pre-filled with the event data" do
      event = create(
        :stocking_event, :loading,
        batch_stocking: batch_stocking, customer: customer, supplier: supplier,
        loading_destination: "Tanque 5", gta_number: "111222"
      )

      get edit_loading_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Editar lançamento")
      expect(response.body).to include("Tanque 5")
      expect(response.body).to include("111222")
      expect(response.body).to include(
        %(<option selected="selected" value="#{supplier.id}">#{supplier.name}</option>)
      )
    end
  end

  describe "PATCH /loading_events/:id" do
    it "updates the loading event" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      patch loading_event_path(event), params: {
        stocking_event: { loading_destination: "Tanque 5" }
      }

      expect(response).to redirect_to(loading_events_path(batch_stocking_id: batch_stocking.id))
      expect(event.reload.loading_destination).to eq("Tanque 5")
    end

    it "updates the supplier" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      patch loading_event_path(event), params: {
        stocking_event: { supplier_id: supplier.id }
      }

      expect(event.reload.supplier).to eq(supplier)
    end
  end

  describe "DELETE /loading_events/:id" do
    it "removes the loading event" do
      event = create(:stocking_event, :loading, batch_stocking: batch_stocking)

      expect do
        delete loading_event_path(event)
      end.to change { batch_stocking.stocking_events.where(event_type: "loading").count }.by(-1)

      expect(response).to redirect_to(loading_events_path(batch_stocking_id: batch_stocking.id))
    end
  end
end
