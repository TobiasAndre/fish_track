class PayrollItemsController < ApplicationController
  before_action :authenticate_user!
  
  def create
    item = PayrollItem.new(payroll_item_params)
    item.item_type ||= "advance"

    item.save!
    redirect_to payroll_path(year: item.year, month: item.month), notice: "Adiantamento lançado!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to payroll_path(year: payroll_item_params[:year], month: payroll_item_params[:month]),
                alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    item = PayrollItem.find(params[:id])

    year  = item.year
    month = item.month

    item.destroy!
    redirect_to payroll_path(year: year, month: month), notice: "Registro removido!"
  end

  private

  def payroll_item_params
    params.require(:payroll_item).permit(:employee_id, :year, :month, :amount_cents, :notes, :item_type)
  end
end
