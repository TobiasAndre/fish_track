class PayrollItemsController < ApplicationController
  before_action :authenticate_user!

  ITEM_TYPE_LABELS = { "advance" => "Adiantamento", "bonus" => "Bônus", "discount" => "Desconto" }.freeze

  def create
    item = PayrollItem.new(payroll_item_params)
    item.item_type ||= "advance"
    item.occurred_on ||= Date.new(item.year.to_i, item.month.to_i, 1)

    item.save!

    label = ITEM_TYPE_LABELS.fetch(item.item_type, "Lançamento")
    redirect_to payroll_path(year: item.year, month: item.month), notice: "#{label} lançado!"
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
    params.require(:payroll_item).permit(:employee_id, :year, :month, :amount_cents, :notes, :item_type, :occurred_on)
  end
end
