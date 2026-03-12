class PaymentMethodsController < ApplicationController
  before_action :set_payment_method, only: %i[edit update destroy]

  def index
    @payment_methods = PaymentMethod.order(:name)
  end

  def new
    @payment_method = PaymentMethod.new(active: true)
  end

  def create
    @payment_method = PaymentMethod.new(payment_method_params)

    if @payment_method.save
      redirect_to payment_methods_path, notice: "Forma de pagamento criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment_method.update(payment_method_params)
      redirect_to payment_methods_path, notice: "Forma de pagamento atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment_method.destroy
    redirect_to payment_methods_path, notice: "Forma de pagamento removida com sucesso."
  end

  private

  def set_payment_method
    @payment_method = PaymentMethod.find(params[:id])
  end

  def payment_method_params
    params.require(:payment_method).permit(:name, :description, :active)
  end
end
