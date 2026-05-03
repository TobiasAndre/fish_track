class SimulationsController < ApplicationController
  before_action :set_simulation, only: %i[show edit update destroy print]
  before_action :load_form_data, only: %i[new create edit update]

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
    @simulation.regenerate_share_token if @simulation.share_token.blank?
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

  def print
    @simulation = Simulation.find(params[:id])

    respond_to do |format|
      format.html
      format.pdf do
        html = render_to_string(
          template: "simulations/print",
          layout: "pdf",
          formats: [:html]
        )

        pdf = WickedPdf.new.pdf_from_string(
          html,
          page_size: "A4",
          encoding: "UTF-8",
          margin: { top: 10, bottom: 10, left: 10, right: 10 }
        )

        send_data pdf,
                  filename: "orcamento-#{@simulation.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @simulation = Simulation.find_by!(
        id: params[:id],
        share_token: params[:share_token]
      )

      respond_to do |format|
        format.pdf do
          render pdf: "orcamento-#{@simulation.id}",
                template: "simulations/print",
                layout: "pdf",
                formats: [:html],
                encoding: "UTF-8",
                page_size: "A4"
        end
      end
    end
  end

  private

  def set_simulation
    @simulation = Simulation.includes(:customer, :products).find(params[:id])
  end

  def load_form_data
    @customers = Customer.order(:name)
    @products = Product.where(active: true).order(:name)
    @integrateds = Integrated.order(:name)
  end

  def simulation_params
    params.require(:simulation).permit(
      :customer_id,
      :simulated_on,
      :integrated_id,
      :quantity,
      :avg_weight_kg,
      :total_weight_kg,
      :price_per_kg_cents,
      :thousand_value_cents,
      :loading_cost_cents,
      :freight_cost_cents,
      :loading_count,
      :total_cents,
      :notes,
      product_ids: []
    )
  end
end
