class PaymentTermsController < ApplicationController
  before_action :set_payment_term, only: %i[edit update destroy]

  def index
    @payment_terms = PaymentTerm.order(:name)
  end

  def new
    @payment_term = PaymentTerm.new(active: true)
  end

  def create
    @payment_term = PaymentTerm.new(payment_term_params)

    if @payment_term.save
      redirect_to payment_terms_path, notice: "Condição de pagamento criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment_term.update(payment_term_params)
      redirect_to payment_terms_path, notice: "Condição de pagamento atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment_term.destroy
    redirect_to payment_terms_path, notice: "Condição de pagamento removida com sucesso."
  end

  private

  def set_payment_term
    @payment_term = PaymentTerm.find(params[:id])
  end

  def payment_term_params
    params.require(:payment_term).permit(:name, :description, :active)
  end
end
