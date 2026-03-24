class IntegratedsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer
  before_action :set_integrated, only: %i[edit update destroy]

  def index
    @integrateds = @customer.integrateds.order(:name)
  end

  def new
    @integrated = @customer.integrateds.new
  end

  def create
    @integrated = @customer.integrateds.new(integrated_params)

    if @integrated.save
      redirect_to customer_integrateds_path(@customer), notice: "Integrado criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @integrated.update(integrated_params)
      redirect_to customer_integrateds_path(@customer), notice: "Integrado atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @integrated.destroy!
    redirect_to customer_integrateds_path(@customer), notice: "Integrado removido com sucesso."
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_integrated
    @integrated = @customer.integrateds.find(params[:id])
  end

  def integrated_params
    params.require(:integrated).permit(
      :name,
      :tax_id,
      :state_registration,
      :email,
      :phone,
      :postal_code,
      :address,
      :address_number,
      :address_complement,
      :neighborhood,
      :city,
      :state,
      :notes
    )
  end
end
