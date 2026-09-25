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
    @feeding_brands = FeedingBrand.order(:name)
    @batches = Batch.order(:status, started_on: :desc)
    @payment_methods = PaymentMethod.where(active: true).order(:name)
    @payment_terms = PaymentTerm.where(active: true).order(:name)
  end

  def load_entries
    @silo_stock_entry ||= SiloStockEntry.new(occurred_on: Date.current)

    @report = SiloStockReport.new(params.permit(*SiloStockReport::FILTER_KEYS))
    @q_silo_id = @report.silo_id
    @q_batch_id = @report.batch_id
    @q_feeding_brand_id = @report.feeding_brand_id
    @q_feeding_type_id = @report.feeding_type_id
    @q_from = @report.from
    @q_to = @report.to
    @filter_feeding_types = @report.filter_feeding_types

    @entries = @report.scope.page(params[:page]).per(15)
    @entries_count = @report.entries_count
    @entries_total_kg = @report.total_kg
    @entries_total_cents = @report.total_cents
    @stock_rows = @report.stock_rows
  end

  def entry_params
    params.require(:silo_stock_entry).permit(
      :silo_id,
      :batch_id,
      :feeding_type_id,
      :payment_method_id,
      :payment_term_id,
      :due_on,
      :occurred_on,
      :quantity_kg,
      :total_cents,
      :notes
    )
  end
end
