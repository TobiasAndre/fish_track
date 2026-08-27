class EmployeesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: :share_termination_report
  before_action :set_employee, only: [:show, :edit, :update, :destroy, :termination_report]
  before_action :load_units, only: [:new, :create, :edit, :update]

  SORTABLE_COLUMNS = {
    "name" => "employees.name",
    "role" => "employees.role",
    "department" => "employees.department",
    "unit" => "units.name",
    "status" => "employees.status",
    "started_on" => "employees.started_on",
    "salary_cents" => "employees.salary_cents"
  }.freeze

  def index
    @employees = Employee.eager_load(:unit)
    @employees = @employees.where("employees.name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @employees = @employees.where(status: params[:status]) if params[:status].present?
    @employees = @employees.where(department: params[:department]) if params[:department].present?
    @employees = @employees.where(unit_id: params[:unit_id]) if params[:unit_id].present?

    @sort_column = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "name"
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    @employees = @employees.order(Arel.sql("#{SORTABLE_COLUMNS[@sort_column]} #{@sort_direction}"))

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

  def termination_report
    @settlement = Employees::TerminationSettlement.new(@employee).call
    @company = Company.find_by(tenant_name: session[:tenant_name])

    respond_to do |format|
      format.html

      format.pdf do
        html = render_to_string(
          template: "employees/termination_report",
          layout: "pdf",
          formats: [:html]
        )

        pdf = WickedPdf.new.pdf_from_string(
          html,
          page_size: "A4",
          encoding: "UTF-8",
          margin: { top: 10, bottom: 10, left: 10, right: 10 }
        )

        send_data pdf,
                  filename: "acerto-rescisorio-#{@employee.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  def share_termination_report
    Apartment::Tenant.switch(params[:tenant_name]) do
      @employee = Employee.find_by!(id: params[:id], share_token: params[:share_token])
      @settlement = Employees::TerminationSettlement.new(@employee).call
      @company = Company.find_by(tenant_name: params[:tenant_name])

      respond_to do |format|
        format.pdf do
          html = render_to_string(
            template: "employees/termination_report",
            layout: "pdf",
            formats: [:html]
          )

          pdf = WickedPdf.new.pdf_from_string(
            html,
            page_size: "A4",
            encoding: "UTF-8",
            margin: { top: 10, bottom: 10, left: 10, right: 10 }
          )

          send_data pdf,
                    filename: "acerto-rescisorio-#{@employee.id}.pdf",
                    type: "application/pdf",
                    disposition: "inline"
        end
      end
    end
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
