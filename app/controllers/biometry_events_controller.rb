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

      render :index, status: :unprocessable_entity
    end
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

    return unless @selected_batch_stocking.present?

    last_biometry = StockingEvent
      .where(event_type: event_type, batch_stocking_id: @selected_batch_stocking.id)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    Rails.logger.info("Last biometry for BatchStocking ##{@selected_batch_stocking.id}: #{last_biometry.inspect}")

    @previous_biomass = last_biometry&.biomass.to_f
    @previous_avg_weight = last_biometry&.avg_weight_g.to_f
    @previous_occurred_on = last_biometry&.occurred_on
    @current_avg_weight_g = last_biometry&.avg_weight_g.to_f
  end
end
