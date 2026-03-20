class PondsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pond, only: [:edit, :update, :destroy]
  before_action :normalize_quantities, only: %i[create update]

  def index
    @ponds = Pond.includes(:unit).order(:id)
  end

  def new
    @pond = Pond.new
  end

  def create
    @pond = Pond.new(pond_params)
    # company.ponds é through :units; então precisamos setar unit_id manualmente via params
    # O Rails vai aceitar unit_id porque Pond pertence a Unit.

    if @pond.save
      redirect_to ponds_path, notice: "Tanque criado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @pond.update(pond_params)
      redirect_to ponds_path, notice: "Tanque atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pond.destroy!
    redirect_to ponds_path, notice: "Tanque removido!"
  end

  private

  def set_pond
    # garante escopo por company
    @pond = Pond.find(params[:id])
  end

  def normalize_quantities
    return if params[:pond].blank?
    return if params[:pond][:capacity].blank?

    params[:pond][:capacity] = params[:pond][:capacity].to_s.gsub(".", "")
  end

  def pond_params
    params.require(:pond).permit(:unit_id, :name, :capacity, :capacity_unit)
  end
end
