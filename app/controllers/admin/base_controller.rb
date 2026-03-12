module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_system_admin!
    around_action :use_public_tenant

    private

    def require_system_admin!
      return if system_admin?

      redirect_to root_path, alert: "Você não tem permissão para acessar esta área."
    end

    def use_public_tenant(&block)
      Apartment::Tenant.switch("public", &block)
    end
  end
end
