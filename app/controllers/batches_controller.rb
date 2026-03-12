class BatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_products, only: %i[new create edit update]
  before_action :set_batch, only: [:edit, :update, :show, :destroy]

  def index
    @batches = Batch
      .includes(pond: :unit)
      .order(started_on: :desc, created_at: :desc)
      .page(params[:page])
      .per(5)
  end

  def show; end

  def new
    @batch = Batch.new(stage: "juvenile", status: "active", started_on: Date.current)
    @batch.pond_id = params[:pond_id] if params[:pond_id].present?
  end

  def create
    @batch = Batch.new(batch_params)
    ensure_scoped_pond!(@batch.pond_id)

    if @batch.save
      redirect_to batch_path(@batch), notice: "Lote criado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    ensure_scoped_pond!(batch_params[:pond_id]) if batch_params[:pond_id].present?

    if @batch.update(batch_params)
      redirect_to batch_path(@batch), notice: "Lote atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @batch.destroy!
    redirect_to batches_path, notice: "Lote removido!"
  end

  private

  def load_products
    @products = Product.order(:name)
  end

  def set_batch
    @batch = Batch.find(params[:id])
  end

  def ensure_scoped_pond!(pond_id)
    return if pond_id.blank?
    Pond.find(pond_id) # levanta ActiveRecord::RecordNotFound se não for da empresa
  end

  def batch_params
    params.require(:batch).permit(
      :pond_id,
      :name,
      :species,
      :status,
      :stage,
      :started_on,
      :closed_on,
      :initial_quantity,
      :current_quantity,
      :avg_weight_g
    )
  end
end
