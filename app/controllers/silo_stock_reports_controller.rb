class SiloStockReportsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: :share_pdf

  def index
    load_report(params.permit(*SiloStockReport::FILTER_KEYS).to_h)

    respond_to do |format|
      format.html
      format.pdf { render_report_pdf }
    end
  end

  def create_share
    filters = SiloStockReport.new(params.permit(*SiloStockReport::FILTER_KEYS).to_h).filters

    report_share = ReportShare.create!(report_type: "silo_stock_report", filters: filters)

    redirect_to silo_stock_reports_path(filters.merge(report_share_id: report_share.id))
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @report_share = ReportShare.find_by!(id: params[:id], share_token: params[:share_token], report_type: "silo_stock_report")
      load_report(@report_share.filters.with_indifferent_access)

      respond_to do |format|
        format.pdf { render_report_pdf }
      end
    end
  end

  private

  def load_report(filters)
    @report = SiloStockReport.new(filters)
    @silos = Silo.includes(:unit).order("units.name", "silos.name").references(:unit)
    @batches = Batch.order(:name)
    @feeding_brands = FeedingBrand.order(:name)
    @filter_feeding_types = @report.filter_feeding_types

    @entries = @report.scope.to_a
    @entries_total_kg = @report.total_kg
    @entries_total_cents = @report.total_cents
    @stock_rows = @report.stock_rows
    @stock_total_kg = @report.stock_total_kg
  end

  def render_report_pdf
    render pdf: "relatorio-estoque-racao",
          template: "silo_stock_reports/index",
          layout: "pdf",
          encoding: "UTF-8",
          page_size: "A4",
          orientation: "Landscape",
          margin: {
            top: 10,
            bottom: 10,
            left: 8,
            right: 8
          }
  end
end
