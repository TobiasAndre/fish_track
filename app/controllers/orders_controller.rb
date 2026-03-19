class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy cancel]
  before_action :load_form_collections, only: %i[new create edit update cancel]

  def index
    @orders = Order.includes(:customer, :payment_method, :payment_term)
                   .order(occurred_on: :desc, created_at: :desc)
                   .page(params[:page])
                   .per(10)
  end

  def show
  end

  def new
    @order = Order.new(
      occurred_on: Date.current,
      status: "draft"
    )
    @order.order_items.build
  end

  def create
    @order = Order.new(order_params)

    if @order.save
      redirect_to orders_path, notice: "Pedido criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @order.order_items.build if @order.order_items.empty?
  end

  def update
    if @order.update(order_params)
      redirect_to orders_path, notice: "Pedido atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    redirect_to orders_path, notice: "Pedido removido com sucesso."
  end

  def cancel
    if @order.delivered?
      redirect_to orders_path, alert: "Pedido já entregue não pode ser cancelado."
      return
    end

    if @order.canceled?
      redirect_to orders_path, notice: "Pedido já está cancelado."
      return
    end

    if @order.update(status: "canceled")
      redirect_to orders_path, notice: "Pedido cancelado com sucesso."
    else
      redirect_to orders_path, alert: "Não foi possível cancelar o pedido."
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def load_form_collections
    @customers = Customer.order(:name)
    @payment_methods = PaymentMethod.where(active: true).order(:name)
    @payment_terms = PaymentTerm.where(active: true).order(:name)
    @products = Product.where(active: true).order(:name)
  end

  def order_params
    params.require(:order).permit(
      :customer_id,
      :payment_method_id,
      :payment_term_id,
      :status,
      :occurred_on,
      :notes,
      order_items_attributes: [
        :id,
        :product_id,
        :quantity,
        :unit_price_cents,
        :total_cents,
        :_destroy
      ]
    )
  end
end
