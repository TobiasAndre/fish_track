class MortalityEventsController < StockingEventPagesController
  before_action :load_active_batch_stockings, only: [:index]

  def create
    @stocking_event = StockingEvent.new(event_params.merge(event_type: event_type))
    apply_event_calculations(@stocking_event)

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: success_message
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@selected_batch_stocking&.id)
      load_active_batch_stockings

      render :index, status: :unprocessable_entity
    end
  end

  private

  def event_type
    "mortality"
  end

  def redirect_path_for(batch_stocking_id)
    mortality_events_path(batch_stocking_id:)
  end

  def success_message
    "Mortalidade lançada com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :quantity,
      :notes
    )
  end

  def load_active_batch_stockings
    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence
    @ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id).order(:name) : Pond.order(:name)
    @selected_pond_id = params[:pond_id].presence

    @active_batch_stockings =
      BatchStocking
        .includes(:batch, :pond, :mortality_events)
        .joins(:batch, :pond)
        .where(batches: { status: "active" })

    @active_batch_stockings = @active_batch_stockings.where(ponds: { unit_id: @selected_unit_id }) if @selected_unit_id.present?
    @active_batch_stockings = @active_batch_stockings.where(pond_id: @selected_pond_id) if @selected_pond_id.present?

    @active_batch_stockings = @active_batch_stockings.order("batches.name ASC", "batch_stockings.stocked_on DESC")
  end
end
