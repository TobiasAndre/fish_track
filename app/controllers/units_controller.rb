class UnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_company!
  before_action :set_unit, only: [:edit, :update, :destroy]

  def index
    @units = current_user.company.units.order(:name)
  end

  def new
    @unit = current_user.company.units.new
  end

  def create
    @unit = current_user.company.units.new(unit_params)

    if @unit.save
      redirect_to units_path, notice: "Unidade criada!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @unit.update(unit_params)
      redirect_to units_path, notice: "Unidade atualizada!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @unit.destroy!
    redirect_to units_path, notice: "Unidade removida!"
  end

  private

  def require_company!
    redirect_to new_company_path, alert: "Crie sua empresa primeiro." if current_user.company.blank?
  end

  def set_unit
    @unit = current_user.company.units.find(params[:id])
  end

  def unit_params
    params.require(:unit).permit(:name)
  end
end
