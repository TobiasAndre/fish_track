class LoadingReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    @batches = Batch.order(:name)
    @ponds = Pond.order(:name)
    @integrateds = Integrated.order(:name)

    @events = StockingEvent
      .where(event_type: "loading")
      .joins(:batch_stocking)
      .includes(:customer, :integrated, :supplier, :payment_method, batch_stocking: %i[batch pond])

    @events = @events.where("stocking_events.occurred_on >= ?", params[:start_date]) if params[:start_date].present?
    @events = @events.where("stocking_events.occurred_on <= ?", params[:end_date]) if params[:end_date].present?
    @events = @events.where(integrated_id: params[:integrated_id]) if params[:integrated_id].present?
    @events = @events.where(batch_stockings: { batch_id: params[:batch_id] }) if params[:batch_id].present?
    @events = @events.where(batch_stockings: { pond_id: params[:pond_id] }) if params[:pond_id].present?

    @events = @events.order(occurred_on: :desc, created_at: :desc)

    @total_quantity = @events.sum(:quantity)
    @total_weight_kg = @events.sum(:total_weight_kg)
    @total_cents = @events.sum(:total_cents)

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "relatorio-carregamentos",
              template: "loading_reports/index",
              layout: "pdf",
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
  end
end
