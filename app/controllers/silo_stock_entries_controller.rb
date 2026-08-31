class SiloStockEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_form_collections
  before_action :load_entries, only: %i[index create update]

  def index
    @silo_stock_entry = SiloStockEntry.new(occurred_on: Date.current)
  end

  def create
    @silo_stock_entry = SiloStockEntry.new(entry_params)

    if @silo_stock_entry.save
      redirect_to silo_stock_entries_path, notice: "Estoque lançado com sucesso."
    else
      load_entries
      render :index, status: :unprocessable_content
    end
  end

  def edit
    @silo_stock_entry = SiloStockEntry.find(params[:id])
    load_entries

    render :index
  end

  def update
    @silo_stock_entry = SiloStockEntry.find(params[:id])

    if @silo_stock_entry.update(entry_params)
      redirect_to silo_stock_entries_path, notice: "Lançamento atualizado com sucesso."
    else
      load_entries
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @silo_stock_entry = SiloStockEntry.find(params[:id])
    @silo_stock_entry.destroy
    redirect_to silo_stock_entries_path, notice: "Lançamento removido com sucesso."
  end

  private

  def load_form_collections
    @silos = Silo.includes(:unit).order("units.name", "silos.name")
    @feeding_types = FeedingType.includes(:feeding_brand).order(:name)
    @batches = Batch.order(:status, started_on: :desc)
  end

  def load_entries
    @silo_stock_entry ||= SiloStockEntry.new(occurred_on: Date.current)

    @q_unit_id = params[:unit_id].presence
    @q_silo_id = params[:silo_id].presence
    @q_feeding_type_id = params[:feeding_type_id].presence
    @q_from = params[:from].presence
    @q_to = params[:to].presence

    scope = SiloStockEntry.includes(:batch, silo: :unit, feeding_type: :feeding_brand)
      .left_joins(:silo)
      .recent_first

    scope = scope.where(silos: { unit_id: @q_unit_id }) if @q_unit_id.present?
    scope = scope.where(silo_id: @q_silo_id) if @q_silo_id.present?
    scope = scope.where(feeding_type_id: @q_feeding_type_id) if @q_feeding_type_id.present?
    scope = scope.where("silo_stock_entries.occurred_on >= ?", @q_from) if @q_from.present?
    scope = scope.where("silo_stock_entries.occurred_on <= ?", @q_to) if @q_to.present?

    @entries = scope.page(params[:page]).per(15)

    @current_stock = SiloStockEntry.group(:silo_id, :feeding_type_id).sum(:quantity_kg)
  end

  def entry_params
    params.require(:silo_stock_entry).permit(
      :silo_id,
      :batch_id,
      :feeding_type_id,
      :occurred_on,
      :quantity_kg,
      :total_cents,
      :notes
    )
  end
end
