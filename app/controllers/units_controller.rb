class UnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_unit, only: [:edit, :update, :destroy]

  def index
    @units = Unit.order(:name)
  end

  def new
    @unit = Unit.new
  end

  def create
    @unit = Unit.new(unit_params)

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

  def set_unit
    @unit = Unit.find(params[:id])
  end

  def unit_params
    params.require(:unit).permit(:name)
  end
end
