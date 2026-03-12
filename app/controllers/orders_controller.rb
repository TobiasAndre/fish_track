class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy]

  def index
    @orders = Order.includes(:customer).order(occurred_on: :desc, created_at: :desc)
  end

  def show
  end

  def new
    @order = Order.new(
      occurred_on: Date.current,
      status: "draft"
    )
    load_customers
  end

  def create
    @order = Order.new(order_params)

    if @order.save
      redirect_to orders_path, notice: "Pedido criado com sucesso."
    else
      load_customers
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_customers
  end

  def update
    if @order.update(order_params)
      redirect_to orders_path, notice: "Pedido atualizado com sucesso."
    else
      load_customers
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    redirect_to orders_path, notice: "Pedido removido com sucesso."
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def load_customers
    @customers = Customer.order(:name)
  end

  def order_params
    params.require(:order).permit(
      :customer_id,
      :status,
      :occurred_on,
      :total_cents,
      :notes
    )
  end
end
