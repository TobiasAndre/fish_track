class FinancialPaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entry

  def index
    @payment = @entry.payments.build(paid_on: Date.current, amount_cents: @entry.balance_cents)
    @payments = @entry.payments.order(:paid_on, :id)
  end

  def create
    @payment = @entry.payments.build(payment_params)

    if @payment.save
      redirect_to financial_entry_payments_path(@entry), notice: "#{noun} registrado."
    else
      @payments = @entry.payments.where.not(id: nil).order(:paid_on, :id)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @entry.payments.find(params[:id]).destroy!
    redirect_to financial_entry_payments_path(@entry), notice: "#{noun} removido."
  end

  private

  def set_entry
    @entry = FinancialEntry.find(params[:financial_entry_id])
  end

  def noun
    @entry.receivable? ? "Recebimento" : "Pagamento"
  end

  def payment_params
    params.require(:financial_payment).permit(:paid_on, :amount_cents, :notes)
  end
end
