class EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee, only: [:show, :edit, :update, :destroy]

  def index
    @employees = Employee.order(:name)
  end

  def show; end

  def new
    @employee = Employee.new
  end

  def create
    @employee = Employee.new(employee_params)
    if @employee.save
      redirect_to employees_path, notice: "Funcionário criado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @employee.update(employee_params)
      redirect_to employees_path, notice: "Funcionário atualizado!"
    else
      render :edit, status: :unprocessable_entity
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

  def employee_params
    params.require(:employee).permit(:name, :role, :salary_cents)
  end
end
