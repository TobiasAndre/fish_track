class SimulationsController < ApplicationController
  before_action :set_simulation, only: %i[show edit update destroy]
  before_action :load_customers, only: %i[new create edit update]

  def index
    @simulations = Simulation
      .includes(:customer)
      .order(simulated_on: :desc, created_at: :desc)
      .page(params[:page])
      .per(10)
  end

  def show
  end

  def new
    @simulation = Simulation.new(simulated_on: Date.current)
  end

  def create
    @simulation = Simulation.new(simulation_params)

    if @simulation.save
      redirect_to simulations_path, notice: "Simulação criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @simulation.update(simulation_params)
      redirect_to simulations_path, notice: "Simulação atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @simulation.destroy
    redirect_to simulations_path, notice: "Simulação removida com sucesso."
  end

  private

  def set_simulation
    @simulation = Simulation.find(params[:id])
  end

  def load_customers
    @customers = Customer.order(:name)
  end

  def simulation_params
    params.require(:simulation).permit(
      :customer_id,
      :simulated_on,
      :quantity,
      :avg_weight_kg,
      :total_weight_kg,
      :price_per_kg_cents,
      :thousand_value_cents,
      :loading_cost_cents,
      :freight_cost_cents,
      :loading_count,
      :total_cents,
      :notes
    )
  end
end
