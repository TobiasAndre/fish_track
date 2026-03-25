class StockingEventsController < ApplicationController
  before_action :set_batch
  before_action :set_batch_stocking
  before_action :set_stocking_event, only: %i[edit update destroy]
  before_action :set_previous_biomass, only: %i[new edit]


  def index
    @events = @batch_stocking.stocking_events
      .order(occurred_on: :desc, created_at: :desc)

    @events = @events.where(event_type: params[:event_type]) if params[:event_type].present?
    @events = @events.where(occurred_on: params[:date]) if params[:date].present?
  end

  def new
    @stocking_event = @batch_stocking.stocking_events.new(occurred_on: Date.current)
  end

  def create
    @stocking_event = @batch_stocking.stocking_events.new(stocking_event_params)

    if @stocking_event.save
      redirect_to batch_batch_stocking_stocking_events_path(@batch, @batch_stocking),
                  notice: "Evento criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @stocking_event.update(stocking_event_params)
      redirect_to batch_batch_stocking_stocking_events_path(@batch, @batch_stocking),
                  notice: "Evento atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @stocking_event.destroy
    redirect_to batch_batch_stocking_stocking_events_path(@batch, @batch_stocking),
                notice: "Evento removido com sucesso."
  end

  private

  def set_batch
    @batch = Batch.find(params[:batch_id])
  end

  def set_batch_stocking
    @batch_stocking = @batch.batch_stockings
      .includes(:supplier, pond: :unit)
      .find(params[:batch_stocking_id])
  end

  def set_stocking_event
    @stocking_event = @batch_stocking.stocking_events.find(params[:id])
  end

  def set_previous_biomass
    event = action_name == "edit" ? @stocking_event : @batch_stocking.stocking_events.new
    @previous_biomass = previous_biomass_for(event)
  end

  def previous_biomass_for(event)
    scope = @batch_stocking.stocking_events.where(event_type: "biometrics")
    scope = scope.where.not(id: event.id) if event.persisted?

    previous_event =
      if event.occurred_on.present?
        scope
          .where(
            "occurred_on < ? OR (occurred_on = ? AND created_at < ?)",
            event.occurred_on,
            event.occurred_on,
            event.created_at || Time.current
          )
          .order(occurred_on: :desc, created_at: :desc)
          .first
      else
        scope.order(occurred_on: :desc, created_at: :desc).first
      end

    previous_event&.biomass.to_d
  end

  def stocking_event_params
    params.require(:stocking_event).permit(
      :event_type,
      :occurred_on,
      :quantity,
      :avg_weight_g,
      :feed_kg,
      :notes,
      :volume,
      :biomass,
      :total_weight_kg,
      :weight_gain_kg
    )
  end
end
