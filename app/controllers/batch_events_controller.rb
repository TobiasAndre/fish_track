class BatchEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_batch
  before_action :set_event, only: [:edit, :update, :destroy]

  def index
    @events = @batch.batch_events.order(occurred_on: :desc, created_at: :desc)

    @events = @events.where(event_type: params[:event_type]) if params[:event_type].present?
    @events = @events.where(occurred_on: params[:date]) if params[:date].present?
  end

  def new
    @event = @batch.batch_events.new(event_type: :mortality, occurred_on: Date.current)
  end

  def create
    @event = @batch.batch_events.new(event_params)

    if @event.save
      redirect_to batch_path(@batch), notice: "Evento registrado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to batch_path(@batch), notice: "Evento atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy!
    redirect_to batch_path(@batch), notice: "Evento removido!"
  end

  private

  def set_batch
    @batch = Batch.find(params[:batch_id])
  end

  def set_event
    @event = @batch.batch_events.find(params[:id])
  end

  def event_params
    params.require(:batch_event).permit(
      :event_type,
      :occurred_on,
      :quantity,
      :avg_weight_g,
      :feed_kg,
      :notes
    )
  end
end
