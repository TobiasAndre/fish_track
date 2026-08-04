require "rails_helper"

RSpec.describe "BatchReports", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }

  before { sign_in user }

  describe "GET /batch_reports" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get batch_reports_path

      expect(response).to have_http_status(:redirect)
    end

    it "shows an empty state when no batch is selected" do
      get batch_reports_path

      expect(response).to have_http_status(:ok)
    end

    it "lists the events for the selected batch" do
      batch = create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0)

      get batch_reports_path, params: { batch_id: batch.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
