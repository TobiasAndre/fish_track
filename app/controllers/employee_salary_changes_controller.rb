class EmployeeSalaryChangesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee

  def create
    Employees::RegisterSalaryChange.new(
      employee: @employee,
      salary_cents: salary_change_params[:salary_cents],
      effective_on: salary_change_params[:effective_on],
      change_type: salary_change_params[:change_type],
      reason: salary_change_params[:reason],
      created_by: current_user
    ).call

    redirect_to employee_path(@employee), notice: "Alteração salarial registrada!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to employee_path(@employee), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def salary_change_params
    params.require(:employee_salary_change).permit(:salary_cents, :effective_on, :change_type, :reason)
  end
end
