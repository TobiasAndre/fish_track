class Users::SessionsController < Devise::SessionsController
  before_action :load_companies, only: %i[new create]

  def create
    tenant_name = params.dig(resource_name, :tenant_name).to_s.strip

    if tenant_name.blank?
      flash.now[:alert] = "Selecione uma empresa."
      return render :new, status: :unprocessable_entity
    end

    # valida se existe no public (Company é excluded_model)
    company = Apartment::Tenant.switch("public") do
      Company.find_by(tenant_name: tenant_name)
    end

    unless company
      flash.now[:alert] = "Empresa inválida."
      return render :new, status: :unprocessable_entity
    end

    # faz auth no tenant escolhido (seu User é global, isso só garante que o tenant fica ativo)
    Apartment::Tenant.switch(tenant_name) do
      self.resource = warden.authenticate!(auth_options)
      sign_in(resource_name, resource)

      # (recomendado) garante que user tem membership nesse tenant
      Apartment::Tenant.switch("public") do
        membership = Membership.find_by(user_id: resource.id, company_id: company.id)
        unless membership
          sign_out(resource)
          flash.now[:alert] = "Você não tem acesso a esta empresa."
          raise ActiveRecord::RecordNotFound
        end
      end

      session[:tenant_name] = tenant_name
    end

    redirect_to after_sign_in_path_for(resource)
  rescue ActiveRecord::RecordNotFound
    render :new, status: :unprocessable_entity
  rescue Apartment::TenantNotFound
    flash.now[:alert] = "Tenant inválido."
    render :new, status: :unprocessable_entity
  end

  private

  def load_companies
    @companies = Apartment::Tenant.switch("public") do
      Company.order(:name)
    end
  end
end