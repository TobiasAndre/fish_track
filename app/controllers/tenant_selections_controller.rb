class TenantSelectionsController < ApplicationController
  before_action :authenticate_user!

  def new
    @companies = current_user.companies.order(:name)
  end

  def create
    tenant_name = params[:tenant_name].to_s.strip
    company = Apartment::Tenant.switch("public") { Company.find_by(tenant_name: tenant_name) }
    membership = company && Apartment::Tenant.switch("public") do
      Membership.find_by(user_id: current_user.id, company_id: company.id)
    end

    if membership.nil?
      flash.now[:alert] = "Você não tem acesso a esta empresa."
      @companies = current_user.companies.order(:name)
      return render :new, status: :unprocessable_content
    end

    session[:tenant_name] = tenant_name
    remember_tenant(tenant_name)
    redirect_to root_path
  end
end
