class BatchesController < ApplicationController
  before_action :set_batch, only: %i[show edit update destroy]
  before_action :set_form_collections, only: %i[new create edit update]

  def index
    @batches = Batch
      .includes(:product, batch_stockings: [{ pond: :unit }, :supplier])
      .order(started_on: :desc, created_at: :desc)
      .page(params[:page])
      .per(10)
  end

  def new
    @batch = Batch.new(
      status: "active",
      stage: "juvenile",
      started_on: Date.current
    )

    @batch.batch_stockings.build(stocked_on: Date.current)
  end

  def create
    @batch = Batch.new(batch_params)

    if @batch.save
      redirect_to batches_path, notice: "Lote criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @batch.batch_stockings.build(stocked_on: Date.current) if @batch.batch_stockings.empty?
  end

  def update
    if @batch.update(batch_params)
      redirect_to batches_path, notice: "Lote atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @batch.destroy
    redirect_to batches_path, notice: "Lote removido com sucesso."
  end

  private

  def set_batch
    @batch = Batch.find(params[:id])
  end

  def set_form_collections
    @ponds = Pond.includes(:unit).order("units.name ASC, ponds.name ASC")
    @products = Product.order(:name)
    @suppliers = Supplier.order(:name)
  end

  def batch_params
    params.require(:batch).permit(
      :name,
      :species,
      :status,
      :stage,
      :started_on,
      :closed_on,
      :initial_quantity,
      :current_quantity,
      :avg_weight_g,
      :product_id,
      batch_stockings_attributes: [
        :id,
        :pond_id,
        :supplier_id,
        :quantity,
        :stocked_on,
        :avg_weight_g,
        :_destroy
      ]
    )
  end
end
