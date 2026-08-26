class PayrollItemsController < ApplicationController
  before_action :authenticate_user!

  ITEM_TYPE_LABELS = {
    "advance" => "Adiantamento",
    "thirteenth_advance" => "Adiantamento 13º",
    "bonus" => "Bônus",
    "discount" => "Desconto"
  }.freeze

  INSTALLABLE_ITEM_TYPES = %w[advance thirteenth_advance].freeze

  def create
    if installment_advance?
      create_installments!
    else
      item = PayrollItem.new(payroll_item_params)
      item.item_type ||= "advance"
      item.occurred_on ||= Date.new(item.year.to_i, item.month.to_i, 1)

      item.save!

      label = ITEM_TYPE_LABELS.fetch(item.item_type, "Lançamento")
      redirect_to payroll_path(year: item.year, month: item.month), notice: "#{label} lançado!"
    end
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

  def installments_count
    params[:installments_count].to_i.clamp(1, 36)
  end

  def installment_advance?
    INSTALLABLE_ITEM_TYPES.include?(payroll_item_params[:item_type]) && installments_count > 1
  end

  def create_installments!
    item_type = payroll_item_params[:item_type]
    total_cents = payroll_item_params[:amount_cents].to_i
    n = installments_count
    base_cents = total_cents / n
    remainder_cents = total_cents - (base_cents * n)

    start_year  = payroll_item_params[:year].to_i
    start_month = payroll_item_params[:month].to_i

    PayrollItem.transaction do
      n.times do |i|
        competence = Date.new(start_year, start_month, 1) + i.months
        amount_cents = base_cents + (i == n - 1 ? remainder_cents : 0)

        PayrollItem.create!(
          employee_id: payroll_item_params[:employee_id],
          year: competence.year,
          month: competence.month,
          item_type: item_type,
          amount_cents: amount_cents,
          occurred_on: competence,
          notes: payroll_item_params[:notes],
          installment_number: i + 1,
          installments_count: n
        )
      end
    end

    label = ITEM_TYPE_LABELS.fetch(item_type, "Lançamento")
    redirect_to payroll_path(year: start_year, month: start_month), notice: "#{label} parcelado em #{n}x lançado!"
  end
end
