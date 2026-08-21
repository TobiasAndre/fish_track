class BiometryEventsController < StockingEventPagesController
  before_action :load_previous_biometry_data, only: [:index]

  def create
    @stocking_event = StockingEvent.new(event_params.merge(event_type: event_type))

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: success_message
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@selected_batch_stocking&.id)
      load_previous_biometry_data

      render :index, status: :unprocessable_content
    end
  end

  def edit
    @stocking_event = StockingEvent.find(params[:id])
    @selected_batch_stocking = @stocking_event.batch_stocking
    @events = filtered_events(@selected_batch_stocking&.id)
    load_previous_biometry_data

    render :index
  end

  def update
    @stocking_event = StockingEvent.find(params[:id])
    @stocking_event.assign_attributes(event_params)

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: "Biometria atualizada com sucesso."
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@selected_batch_stocking&.id)
      load_previous_biometry_data

      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @stocking_event = StockingEvent.find(params[:id])
    batch_stocking_id = @stocking_event.batch_stocking_id
    @stocking_event.destroy
    redirect_to redirect_path_for(batch_stocking_id), notice: "Biometria removida com sucesso."
  end

  private

  def event_type
    "biometrics"
  end

  def redirect_path_for(batch_stocking_id)
    biometry_events_path(batch_stocking_id:)
  end

  def success_message
    "Biometria lançada com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :volume,
      :quantity,
      :total_weight_kg,
      :avg_weight_g,
      :biomass,
      :weight_gain_kg,
      :gpd,
      :feed_kg,
      :feed_conversion,
      :notes
    )
  end

  def load_previous_biometry_data
    @previous_biomass = 0
    @previous_avg_weight = 0
    @previous_occurred_on = nil
    @current_avg_weight_g = 0

    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence
    @ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id).order(:name) : Pond.order(:name)
    @selected_pond_id = params[:pond_id].presence

    @active_batch_stockings =
      BatchStocking
        .includes(:batch, :pond, :biometry_events)
        .joins(:batch, :pond)
        .where(batches: { status: "active" })

    @active_batch_stockings = @active_batch_stockings.where(ponds: { unit_id: @selected_unit_id }) if @selected_unit_id.present?
    @active_batch_stockings = @active_batch_stockings.where(pond_id: @selected_pond_id) if @selected_pond_id.present?

    @active_batch_stockings = @active_batch_stockings.order("batches.name ASC", "batch_stockings.stocked_on DESC")

    return unless @selected_batch_stocking.present?

    last_biometry = StockingEvent
      .where(event_type: event_type, batch_stocking_id: @selected_batch_stocking.id)
      .where.not(id: @stocking_event&.id)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    Rails.logger.info("Last biometry for BatchStocking ##{@selected_batch_stocking.id}: #{last_biometry.inspect}")

    @previous_biomass = last_biometry&.biomass.to_f
    @previous_avg_weight = last_biometry&.avg_weight_g.to_f
    @previous_occurred_on = last_biometry&.occurred_on
    @current_avg_weight_g = last_biometry&.avg_weight_g.to_f
  end
end
