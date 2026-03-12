class ApplicationController < ActionController::Base
  helper_method :system_admin?
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :switch_tenant
  helper_method :current_profile

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :tenant_name])
  end

  private

  def switch_tenant(&block)
    tenant = session[:tenant_name].presence || "public"
    Apartment::Tenant.switch(tenant, &block)
  rescue Apartment::TenantNotFound
    reset_session
    redirect_to new_user_session_path, alert: "Tenant inválido."
  end

  def system_admin?
    user_signed_in? && current_user.email == "admin@fishtrack.com"
  end

  def current_profile
    return nil unless user_signed_in?

    @current_profile ||= Profile.find_or_create_by!(
      user_id: current_user.id
    ) do |profile|
      profile.display_name = current_user.email
    end
  end
end
