class BatchReportsController < ApplicationController
  def index
    load_batch_report(params.permit(:batch_id, :event_type, :start_date, :end_date).to_h)

    respond_to do |format|
      format.html
      format.pdf { render_batch_report_pdf }
    end
  end

  def create_share
    filters = {
      batch_id: params[:batch_id],
      event_type: params[:event_type],
      start_date: params[:start_date],
      end_date: params[:end_date]
    }.compact_blank

    report_share = ReportShare.create!(report_type: "batch_report", filters: filters)

    redirect_to batch_reports_path(filters.merge(report_share_id: report_share.id))
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @report_share = ReportShare.find_by!(id: params[:id], share_token: params[:share_token], report_type: "batch_report")
      load_batch_report(@report_share.filters.with_indifferent_access)

      respond_to do |format|
        format.pdf { render_batch_report_pdf }
      end
    end
  end

  private

  def load_batch_report(filters)
    @batches = Batch.order(:name)
    @batch = Batch.includes(batch_stockings: [:pond, :stocking_events]).find_by(id: filters[:batch_id])

    @events = StockingEvent.none

    if @batch.present?
      @events = @batch.stocking_events
                      .includes(batch_stocking: :pond)
                      .order(occurred_on: :asc, created_at: :asc)

      @events = @events.where(event_type: filters[:event_type]) if filters[:event_type].present?
      @events = @events.where("occurred_on >= ?", filters[:start_date]) if filters[:start_date].present?
      @events = @events.where("occurred_on <= ?", filters[:end_date]) if filters[:end_date].present?
    end
  end

  def render_batch_report_pdf
    render pdf: "relatorio-lote-#{@batch&.id}",
          template: "batch_reports/index",
          layout: "pdf",
          page_size: "A4",
          margin: {
            top: 10,
            bottom: 10,
            left: 8,
            right: 8
          }
  end
end
