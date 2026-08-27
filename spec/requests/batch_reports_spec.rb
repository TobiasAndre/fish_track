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

  describe "POST /batch_reports/create_share" do
    it "creates a ReportShare with the current filters and redirects back with report_share_id" do
      batch = create(:batch, pond: pond)

      expect do
        post create_share_batch_reports_path, params: { batch_id: batch.id, event_type: "loading" }
      end.to change(ReportShare, :count).by(1)

      report_share = ReportShare.last
      expect(report_share.report_type).to eq("batch_report")
      expect(report_share.filters).to eq("batch_id" => batch.id.to_s, "event_type" => "loading")
      expect(response).to redirect_to(
        batch_reports_path(batch_id: batch.id, event_type: "loading", report_share_id: report_share.id)
      )
    end
  end

  describe "GET /shared/:tenant_name/batch_reports/:id/:share_token" do
    it "renders the PDF publicly, without requiring authentication" do
      sign_out user
      batch = create(:batch, pond: pond)
      report_share = create(:report_share, report_type: "batch_report", filters: { batch_id: batch.id })

      get shared_batch_report_pdf_path(
        tenant_name: "public", id: report_share.id, share_token: report_share.share_token, format: :pdf
      )

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not found with an invalid share_token" do
      report_share = create(:report_share, report_type: "batch_report")

      get shared_batch_report_pdf_path(
        tenant_name: "public", id: report_share.id, share_token: "wrong-token", format: :pdf
      )

      expect(response).to have_http_status(:not_found)
    end
  end
end
