class BatchReportsController < ApplicationController
  def index
    @batches = Batch.order(:name)
    @batch = Batch.includes(batch_stockings: [:pond, :stocking_events]).find_by(id: params[:batch_id])

    @events = StockingEvent.none

    if @batch.present?
      @events = @batch.stocking_events
                      .includes(batch_stocking: :pond)
                      .order(occurred_on: :asc, created_at: :asc)

      @events = @events.where(event_type: params[:event_type]) if params[:event_type].present?
      @events = @events.where("occurred_on >= ?", params[:start_date]) if params[:start_date].present?
      @events = @events.where("occurred_on <= ?", params[:end_date]) if params[:end_date].present?
    end

    respond_to do |format|
      format.html
      format.pdf do
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
  end
end