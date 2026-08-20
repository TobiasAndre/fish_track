class EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee, only: [:show, :edit, :update, :destroy]
  before_action :load_units, only: [:new, :create, :edit, :update]

  def index
    @employees = Employee.includes(:unit).order(:name)
    @employees = @employees.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @employees = @employees.where(status: params[:status]) if params[:status].present?
    @employees = @employees.where(department: params[:department]) if params[:department].present?
    @employees = @employees.where(unit_id: params[:unit_id]) if params[:unit_id].present?

    @departments = Employee.where.not(department: [nil, ""]).distinct.order(:department).pluck(:department)
    @units = Unit.order(:name)
  end

  def show
    @salary_changes = @employee.salary_changes
    @vacations = @employee.vacations
    @alerts = EmployeeAlerts.new(@employee).call
    @new_salary_change = EmployeeSalaryChange.new(effective_on: Date.current, change_type: "adjustment")
    @new_vacation = EmployeeVacation.new(employee: @employee, accrual_started_on: @employee.started_on)
  end

  def new
    @employee = Employee.new(started_on: Date.current)
  end

  def create
    @employee = Employee.new(employee_params)
    if @employee.save
      redirect_to employees_path, notice: "Funcionário criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    # salary_cents is intentionally excluded here: once an employee exists,
    # it must only change through Employees::RegisterSalaryChange so the
    # history in employee_salary_changes stays the source of truth.
    if @employee.update(employee_params.except(:salary_cents))
      redirect_to employees_path, notice: "Funcionário atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @employee.destroy!
    redirect_to employees_path, notice: "Funcionário removido!"
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def load_units
    @units = Unit.order(:name)
  end

  def employee_params
    params.require(:employee).permit(
      :name, :role, :salary_cents, :started_on,
      :department, :status, :terminated_on, :notes, :unit_id
    )
  end
end
