class CompaniesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company, only: [:edit, :update]

  def new
    redirect_to edit_company_path(current_user.company) if current_user.company.present?
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      # vincula o usuário à empresa
      current_user.update!(company: @company)

      # cria uma unidade default (Sede) pra começar
      @company.units.create!(name: "Sede")

      redirect_to units_path, notice: "Empresa criada com sucesso!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @company.update(company_params)
      redirect_to units_path, notice: "Empresa atualizada com sucesso!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_company
    @company = current_user.company
    redirect_to new_company_path, alert: "Crie sua empresa primeiro." if @company.blank?
  end

  def company_params
    params.require(:company).permit(:name)
  end
end
