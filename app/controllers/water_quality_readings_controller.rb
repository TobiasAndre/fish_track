class WaterQualityReadingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reading, only: %i[edit update destroy]

  DEFAULT_PERIOD_DAYS = 30

  def index
    @reading = WaterQualityReading.new(measured_at: Time.current.change(sec: 0), pond_id: params[:pond_id].presence)
    load_page
  end

  def create
    @reading = WaterQualityReading.new(reading_params)

    if @reading.save
      redirect_to water_quality_readings_path(page_filters.merge(pond_id: @reading.pond_id)),
        notice: "Análise lançada com sucesso."
    else
      load_page
      render :index, status: :unprocessable_content
    end
  end

  def edit
    load_page(pond_id: @reading.pond_id)
    render :index
  end

  def update
    if @reading.update(reading_params)
      redirect_to water_quality_readings_path(page_filters.merge(pond_id: @reading.pond_id)),
        notice: "Análise atualizada com sucesso."
    else
      load_page
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    pond_id = @reading.pond_id
    @reading.destroy
    redirect_to water_quality_readings_path(page_filters.merge(pond_id: pond_id)), notice: "Análise removida com sucesso."
  end

  private

  def set_reading
    @reading = WaterQualityReading.find(params[:id])
  end

  def load_page(pond_id: params[:pond_id].presence)
    @ponds = Pond.joins(:unit).includes(:unit).order("units.name", :order_number, :id).to_a
    @latest_by_pond_id = WaterQualityReading.latest_by_pond_id

    # Tanque do gráfico: o escolhido; senão, o da análise mais recente.
    @selected_pond = @ponds.find { |pond| pond.id.to_s == pond_id.to_s }
    @selected_pond ||= @ponds.find { |pond| pond.id == @latest_by_pond_id.values.max_by(&:measured_at)&.pond_id }

    @to = parse_date(params[:to]) || Date.current
    @from = parse_date(params[:from]) || (@to - (DEFAULT_PERIOD_DAYS - 1))
    @from, @to = @to, @from if @from > @to

    @readings =
      if @selected_pond
        @selected_pond.water_quality_readings.measured_between(@from, @to).chronological.to_a
      else
        []
      end
  end

  def reading_params
    params.require(:water_quality_reading).permit(:pond_id, :measured_at, :ph, :nitrite, :ammonia, :alkalinity, :salinity, :notes)
  end

  # Período do gráfico, preservado depois de salvar/editar/excluir.
  def page_filters
    { from: params[:from].presence, to: params[:to].presence }.compact
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end
end
