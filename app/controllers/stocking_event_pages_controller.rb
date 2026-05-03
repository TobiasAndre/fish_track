class StockingEventPagesController < ApplicationController
  before_action :load_batch_stockings
  before_action :load_selected_batch_stocking
  before_action :load_current_avg_weight
  before_action :load_loading_form_collections

  def index
    @stocking_event = build_event
    @events = filtered_events
  end

  def create
    @stocking_event = build_event_from_params

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking),
        notice: "Lançamento registrado com sucesso."
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
      @events = filtered_events(@stocking_event.batch_stocking_id)

      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @stocking_event = StockingEvent.find(params[:id])
    @selected_batch_stocking = @stocking_event.batch_stocking
    @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
    @events = filtered_events(@stocking_event.batch_stocking_id)
  end

  def update
    @stocking_event = StockingEvent.find(params[:id])
    @stocking_event.assign_attributes(event_params)
    apply_event_calculations(@stocking_event)

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking),
        notice: "Lançamento atualizado com sucesso."
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
      @events = filtered_events(@stocking_event.batch_stocking_id)

      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @stocking_event = StockingEvent.find(params[:id])
    batch_stocking = @stocking_event.batch_stocking
    @stocking_event.destroy
    redirect_to redirect_path_for(batch_stocking), notice: "Lançamento removido com sucesso."
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

  def load_current_avg_weight
    @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
  end

  def load_loading_form_collections
    return unless event_type == "loading"

    @customers = Customer.order(:name)
    @integrateds = Supplier.order(:name)
    @payment_methods = PaymentMethod.order(:name)
  end

  def build_event
    StockingEvent.new(
      event_type: event_type,
      batch_stocking: @selected_batch_stocking,
      occurred_on: Date.current
    )
  end

  def build_event_from_params
    event = StockingEvent.new(event_params)
    event.event_type = event_type

    apply_event_calculations(event)

    event
  end

  def apply_event_calculations(event)
    return unless event.event_type == "mortality"
    return if event.batch_stocking.blank?

    avg_weight_g = current_avg_weight_for(event.batch_stocking)
    quantity = event.quantity.to_i

    event.avg_weight_g = avg_weight_g
    event.total_weight_kg = quantity * avg_weight_g / 1000
  end

  def current_avg_weight_for(batch_stocking)
    return 0 if batch_stocking.blank?

    last_biometry = StockingEvent
      .where(event_type: "biometrics", batch_stocking: batch_stocking)
      .where.not(avg_weight_g: nil)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    last_biometry&.avg_weight_g || batch_stocking.avg_weight_g || 0
  end

  def filtered_events(batch_stocking_id = @selected_batch_stocking&.id)
    return StockingEvent.none if batch_stocking_id.blank?

    StockingEvent
      .where(event_type: event_type, batch_stocking_id: batch_stocking_id)
      .order(occurred_on: :desc, created_at: :desc)
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :quantity,
      :volume,
      :total_weight_kg,
      :avg_weight_g,
      :biomass,
      :weight_gain_kg,
      :gpd,
      :feed_kg,
      :feed_conversion,
      :notes,
      :customer_id,
      :integrated_id,
      :payment_date,
      :price_per_kg_cents,
      :thousand_value_cents,
      :freight_cost_cents,
      :loading_cost_cents,
      :payment_method_id
    )
  end
end
