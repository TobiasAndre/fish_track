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
    restore_remembered_tenant if session[:tenant_name].blank? && user_signed_in?

    tenant = session[:tenant_name].presence || "public"
    Apartment::Tenant.switch(tenant, &block)
  rescue Apartment::TenantNotFound
    session.delete(:tenant_name)
    forget_remembered_tenant
    redirect_to user_signed_in? ? select_company_path : new_user_session_path,
      alert: "Empresa inválida. Selecione novamente."
  end

  # Mirrors Devise's "remember me" cookie so a returning user (restored via
  # the rememberable cookie after their session expired) doesn't have to
  # pick their company again on every new browser session.
  def restore_remembered_tenant
    remembered_tenant_name = cookies.signed[:remembered_tenant_name].presence
    return if remembered_tenant_name.blank?

    valid = Apartment::Tenant.switch("public") do
      company = Company.find_by(tenant_name: remembered_tenant_name)
      company.present? && Membership.exists?(user_id: current_user.id, company_id: company.id)
    end

    if valid
      session[:tenant_name] = remembered_tenant_name
    else
      cookies.delete(:remembered_tenant_name)
    end
  end

  def remember_tenant(tenant_name)
    cookies.signed[:remembered_tenant_name] = {
      value: tenant_name,
      expires: Devise.remember_for.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  def forget_remembered_tenant
    cookies.delete(:remembered_tenant_name)
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
