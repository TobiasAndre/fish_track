class StockingEventsController < ApplicationController
  before_action :set_batch_stocking
  before_action :set_stocking_event, only: %i[edit update destroy]
  before_action :set_previous_biometry_data, only: %i[new edit]
  before_action :set_current_avg_weight, only: %i[new edit]
  before_action :load_loading_form_data, only: %i[new edit create update]

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
      redirect_to batch_batch_stocking_stocking_events_path(@batch_stocking.batch, @batch_stocking),
        notice: "Evento criado com sucesso."
    else
      set_previous_biometry_data_for(@stocking_event)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @stocking_event.update(stocking_event_params)
      redirect_to batch_batch_stocking_stocking_events_path(@batch_stocking.batch, @batch_stocking),
        notice: "Evento atualizado com sucesso."
    else
      set_previous_biometry_data_for(@stocking_event)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @stocking_event.destroy
    redirect_to batch_batch_stocking_stocking_events_path(@batch_stocking.batch, @batch_stocking),
      notice: "Evento removido com sucesso."
  end

  private

  def set_batch_stocking
    @batch_stocking = BatchStocking.includes(:batch, pond: :unit).find(params[:batch_stocking_id])
    @batch = @batch_stocking.batch
  end

  def load_loading_form_data
    @customers = Customer.order(:name)
    @integrateds = Integrated.order(:name)
    @payment_methods = PaymentMethod.order(:name)
  end

  def set_stocking_event
    @stocking_event = @batch_stocking.stocking_events.find(params[:id])
  end

  def set_previous_biometry_data
    event =
      if action_name == "edit"
        @stocking_event
      else
        @batch_stocking.stocking_events.new(occurred_on: Date.current)
      end

    set_previous_biometry_data_for(event)
  end

  def set_previous_biometry_data_for(event)
    previous_event = previous_biometry_event_for(event)

    @previous_biomass = previous_event&.biomass.to_d
    @previous_avg_weight = previous_event&.avg_weight_g.to_d
    @previous_occurred_on = previous_event&.occurred_on
  end

  def set_current_avg_weight
    latest_biometry = @batch_stocking.stocking_events
      .where(event_type: "biometrics")
      .order(occurred_on: :desc, created_at: :desc)
      .first

    @current_avg_weight_g =
      latest_biometry&.avg_weight_g ||
      @batch_stocking.avg_weight_g ||
      @batch.avg_weight_g ||
      0
  end

  def previous_biometry_event_for(event)
    scope = @batch_stocking.stocking_events.where(event_type: "biometrics")
    scope = scope.where.not(id: event.id) if event.persisted?

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
      scope
        .order(occurred_on: :desc, created_at: :desc)
        .first
    end
  end

  def stocking_event_params
    params.require(:stocking_event).permit(
      :event_type,
      :occurred_on,
      :quantity,
      :avg_weight_g,
      :feed_kg,
      :notes,
      :total_weight_kg,
      :volume,
      :biomass,
      :weight_gain_kg,
      :gpd,
      :price_per_kg_cents,
      :thousand_value_cents,
      :freight_cost_cents,
      :loading_cost_cents,
      :payment_date,
      :payment_method_id,
      :customer_id,
      :integrated_id,
      :feed_kg,
      :feed_conversion
    )
  end
end
