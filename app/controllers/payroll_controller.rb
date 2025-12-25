class PayrollController < ApplicationController
  before_action :authenticate_user!
  before_action :require_company!

  def show
    @company = current_user.company
    @year  = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i

    @employees = @company.employees.order(:name)

    @items_by_employee = @company.payroll_items
      .includes(:employee)
      .where(year: @year, month: @month)
      .order(created_at: :asc)
      .group_by(&:employee_id)

    @new_item = @company.payroll_items.new(year: @year, month: @month, item_type: "advance")
  end

  def update
    company = current_user.company
    year  = params.require(:year).to_i
    month = params.require(:month).to_i

    salaries = params.fetch(:salaries, {}) # { "employee_id" => "123400" }

    PayrollItem.transaction do
      salaries.each do |employee_id, amount_cents|
        employee = company.employees.find(employee_id)
        cents = amount_cents.to_s.gsub(/\D/, "").to_i

        # se vazio/zero, remove o salário do mês
        if cents <= 0
          company.payroll_items.where(employee: employee, year: year, month: month, item_type: "salary").delete_all
          next
        end

        item = company.payroll_items.find_or_initialize_by(
          employee: employee,
          year: year,
          month: month,
          item_type: "salary"
        )

        item.amount_cents = cents
        item.notes = "Salário base #{month}/#{year}"
        item.save!
      end
    end

    redirect_to payroll_path(year: year, month: month), notice: "Salários atualizados!"
  end

  private

  def require_company!
    redirect_to new_company_path, alert: "Crie sua empresa primeiro." if current_user.company.blank?
  end
end
