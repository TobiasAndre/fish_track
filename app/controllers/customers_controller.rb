class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    @customers = Customer.order(:name)
  end

  def show; end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      redirect_to customers_path, notice: "Cliente criado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path, notice: "Cliente atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: "Cliente removido!"
  end

  private

  def customer_params
    params.require(:customer).permit(:name)
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end
end
