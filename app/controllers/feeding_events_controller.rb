class FeedingEventsController < StockingEventPagesController
  before_action :load_feeding_collections
  before_action :load_active_batch_stockings, only: [:index]

  def create
    @stocking_event = build_event_from_params

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: success_message
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@stocking_event.batch_stocking_id)
      load_active_batch_stockings

      render :index, status: :unprocessable_content
    end
  end

  def edit
    @stocking_event = StockingEvent.find(params[:id])
    @selected_batch_stocking = @stocking_event.batch_stocking
    @events = filtered_events(@stocking_event.batch_stocking_id)

    render :index
  end

  def update
    @stocking_event = StockingEvent.find(params[:id])
    @stocking_event.assign_attributes(event_params)

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: "Ração atualizada com sucesso."
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@stocking_event.batch_stocking_id)
      load_active_batch_stockings

      render :index, status: :unprocessable_content
    end
  end

  private

  def event_type
    "feeding"
  end

  def redirect_path_for(batch_stocking_id)
    feeding_events_path(batch_stocking_id:)
  end

  def success_message
    "Ração lançada com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :feeding_type_id,
      :feed_kg,
      :total_cents,
      :notes
    )
  end

  def load_feeding_collections
    @feeding_types = FeedingType.includes(:feeding_brand).order(:name)
  end

  def load_active_batch_stockings
    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence
    @ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id).order(:name) : Pond.order(:name)
    @selected_pond_id = params[:pond_id].presence
    @selected_pond_id = nil if @selected_pond_id.present? && !@ponds.exists?(id: @selected_pond_id)

    @active_batch_stockings =
      BatchStocking
        .includes(:batch, :pond, feeding_events: %i[feeding_type feeding_brand])
        .joins(:batch, :pond)
        .where(batches: { status: "active" })

    @active_batch_stockings = @active_batch_stockings.where(ponds: { unit_id: @selected_unit_id }) if @selected_unit_id.present?
    @active_batch_stockings = @active_batch_stockings.where(pond_id: @selected_pond_id) if @selected_pond_id.present?

    @active_batch_stockings = @active_batch_stockings.order("batches.name ASC", "batch_stockings.stocked_on DESC")
  end
end
