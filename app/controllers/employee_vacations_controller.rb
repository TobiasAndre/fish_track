class EmployeeVacationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee
  before_action :set_vacation, only: [:update]

  def create
    @vacation = @employee.vacations.new(vacation_params)

    if @vacation.save
      redirect_to employee_path(@employee), notice: "Período de férias registrado!"
    else
      redirect_to employee_path(@employee), alert: @vacation.errors.full_messages.to_sentence
    end
  end

  def update
    if @vacation.update(vacation_params)
      redirect_to employee_path(@employee), notice: "Período de férias atualizado!"
    else
      redirect_to employee_path(@employee), alert: @vacation.errors.full_messages.to_sentence
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id])
  end

  def set_vacation
    @vacation = @employee.vacations.find(params[:id])
  end

  def vacation_params
    params.require(:employee_vacation).permit(
      :accrual_started_on,
      :accrual_ended_on,
      :scheduled_start_on,
      :scheduled_end_on,
      :taken_start_on,
      :taken_end_on,
      :status,
      :entitled_days,
      :taken_days,
      :payment_amount_cents,
      :payment_due_on,
      :paid_on,
      :notes
    )
  end
end
