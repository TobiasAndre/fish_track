class PondsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_company!
  before_action :set_pond, only: [:edit, :update, :destroy]

  def index
    @ponds = current_user.company.ponds.includes(:unit).order("units.name ASC, ponds.name ASC")
  end

  def new
    @pond = Pond.new
  end

  def create
    @pond = current_user.company.ponds.new(pond_params)
    # company.ponds é through :units; então precisamos setar unit_id manualmente via params
    # O Rails vai aceitar unit_id porque Pond pertence a Unit.

    if @pond.save
      redirect_to ponds_path, notice: "Açude criado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @pond.update(pond_params)
      redirect_to ponds_path, notice: "Açude atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pond.destroy!
    redirect_to ponds_path, notice: "Açude removido!"
  end

  private

  def require_company!
    redirect_to new_company_path, alert: "Crie sua empresa primeiro." if current_user.company.blank?
  end

  def set_pond
    # garante escopo por company
    @pond = current_user.company.ponds.find(params[:id])
  end

  def pond_params
    params.require(:pond).permit(:unit_id, :name, :capacity, :capacity_unit)
  end
end
