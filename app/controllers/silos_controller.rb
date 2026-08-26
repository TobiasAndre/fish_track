class SilosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_silo, only: [:edit, :update, :destroy]

  def index
    @silos = Silo.includes(:unit).order(:id)
  end

  def new
    @silo = Silo.new
  end

  def create
    @silo = Silo.new(silo_params)

    if @silo.save
      redirect_to silos_path, notice: "Silo criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @silo.update(silo_params)
      redirect_to silos_path, notice: "Silo atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @silo.destroy!
    redirect_to silos_path, notice: "Silo removido!"
  end

  private

  def set_silo
    @silo = Silo.find(params[:id])
  end

  def silo_params
    params.require(:silo).permit(:unit_id, :name)
  end
end
