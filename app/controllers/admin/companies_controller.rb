module Admin
  class CompaniesController < Admin::BaseController
    before_action :set_company, only: %i[edit update]

    def index
      @companies = Company.order(:name)
    end

    def new
      @company = Company.new
      load_users
    end

    def create
      service = Admin::CreateCompanyWithTenant.new(
        company_params: company_params,
        owner_user_id: params[:company][:owner_user_id]
      )

      @company = service.call

      redirect_to admin_companies_path, notice: "Empresa criada com sucesso."
    rescue ActiveRecord::RecordInvalid => e
      @company = e.record.is_a?(Company) ? e.record : Company.new(company_params)
      load_users
      flash.now[:alert] = "Não foi possível criar a empresa."
      render :new, status: :unprocessable_entity
    end

    def edit
      load_users
    end

    def update
      if @company.update(company_params)
        redirect_to admin_companies_path, notice: "Empresa atualizada com sucesso."
      else
        load_users
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_company
      @company = Company.find(params[:id])
    end

    def load_users
      @users = User.order(:name, :email)
    end

    def company_params
      params.require(:company).permit(:name, :tenant_name)
    end
  end
end
