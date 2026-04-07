class StockingEventPagesController < ApplicationController
  before_action :load_batch_stockings
  before_action :load_selected_batch_stocking

  def index
    @stocking_event = build_event
    @events = filtered_events
  end

  private

  def load_batch_stockings
    @batch_stockings = BatchStocking
      .includes(:batch, pond: :unit)
      .order(created_at: :desc)
  end

  def load_selected_batch_stocking
    selected_id = params[:batch_stocking_id] || params.dig(:stocking_event, :batch_stocking_id)
    @selected_batch_stocking = BatchStocking.find_by(id: selected_id)
  end

  def build_event
    StockingEvent.new(
      event_type: event_type,
      batch_stocking: @selected_batch_stocking,
      occurred_on: Date.current
    )
  end

  def filtered_events(batch_stocking_id = @selected_batch_stocking&.id)
    return StockingEvent.none if batch_stocking_id.blank?

    StockingEvent
      .where(event_type: event_type, batch_stocking_id: batch_stocking_id)
      .order(occurred_on: :desc, created_at: :desc)
  end
end
