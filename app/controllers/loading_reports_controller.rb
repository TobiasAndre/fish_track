class LoadingReportsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: :share_pdf

  def index
    load_loading_report(params.permit(:start_date, :end_date, :integrated_id, :batch_id, :pond_id, :customer_id).to_h)

    respond_to do |format|
      format.html
      format.pdf { render_loading_report_pdf }
    end
  end

  def create_share
    filters = {
      start_date: params[:start_date],
      end_date: params[:end_date],
      integrated_id: params[:integrated_id],
      batch_id: params[:batch_id],
      pond_id: params[:pond_id],
      customer_id: params[:customer_id]
    }.compact_blank

    report_share = ReportShare.create!(report_type: "loading_report", filters: filters)

    redirect_to loading_reports_path(filters.merge(report_share_id: report_share.id))
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @report_share = ReportShare.find_by!(id: params[:id], share_token: params[:share_token], report_type: "loading_report")
      load_loading_report(@report_share.filters.with_indifferent_access)

      respond_to do |format|
        format.pdf { render_loading_report_pdf }
      end
    end
  end

  private

  def load_loading_report(filters)
    @batches = Batch.order(:name)
    @ponds = Pond.includes(:unit).joins(:unit).order("units.name ASC, ponds.name ASC")
    @integrateds = Integrated.order(:name)
    @customers = Customer.order(:name)

    @events = StockingEvent
      .where(event_type: "loading")
      .joins(:batch_stocking)
      .includes(:customer, :integrated, :supplier, :payment_method, batch_stocking: %i[batch pond])

    @events = @events.where("stocking_events.occurred_on >= ?", filters[:start_date]) if filters[:start_date].present?
    @events = @events.where("stocking_events.occurred_on <= ?", filters[:end_date]) if filters[:end_date].present?
    @events = @events.where(integrated_id: filters[:integrated_id]) if filters[:integrated_id].present?
    @events = @events.where(batch_stockings: { batch_id: filters[:batch_id] }) if filters[:batch_id].present?
    @events = @events.where(batch_stockings: { pond_id: filters[:pond_id] }) if filters[:pond_id].present?
    @events = @events.where(customer_id: filters[:customer_id]) if filters[:customer_id].present?

    @events = @events.order(occurred_on: :desc, created_at: :desc)

    @total_quantity = @events.sum(:quantity)
    @total_weight_kg = @events.sum(:total_weight_kg)
    @total_cents = @events.sum(:total_cents)
  end

  def render_loading_report_pdf
    render pdf: "relatorio-carregamentos",
          template: "loading_reports/index",
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
