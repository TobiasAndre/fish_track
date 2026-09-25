class ApplicationController < ActionController::Base
  helper_method :system_admin?
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :switch_tenant
  before_action :set_current_request_details
  before_action :enforce_access_profile
  helper_method :current_profile
  helper_method :current_company
  helper_method :can?, :can_here?, :access_policy

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
    user_signed_in? && current_user.system_admin?
  end

  # Perfil de acesso do usuário na empresa selecionada (memoizado por request).
  def access_policy
    @access_policy ||= AccessPolicy.for(user: (current_user if user_signed_in?), company: current_company)
  end

  # Pode o usuário fazer `action` (:read, :write, :edit, :delete) na página `resource_key`?
  def can?(resource_key, action)
    user_signed_in? && access_policy.can?(resource_key.to_s, action.to_s)
  end

  # O mesmo, para a página do controller atual (usado nos botões das telas).
  def can_here?(action)
    resource = PermissionCatalog.resource_for_controller(controller_path)
    resource.nil? || can?(resource.key, action)
  end

  # Barra o acesso a uma página/ação que o perfil do usuário não concede.
  def enforce_access_profile
    return unless user_signed_in?
    return if AccessPolicy.public_action?(action_name)

    resource = PermissionCatalog.resource_for_controller(controller_path)
    return if resource.nil?
    return if can?(resource.key, AccessPolicy.required_action(controller_path, action_name, request.request_method))

    deny_access(resource)
  end

  def deny_access(resource)
    return head(:forbidden) unless request.format.html? || request.format.turbo_stream?
    return redirect_to(select_company_path, alert: "Selecione uma empresa para continuar.") if current_company.nil?

    fallback = access_policy.first_readable_resource(excluding: resource)

    if fallback
      redirect_to public_send(fallback.path_helper), alert: "Você não tem permissão para acessar esta página."
    else
      render "shared/no_access", status: :forbidden
    end
  end

  def current_company
    return nil if session[:tenant_name].blank?

    @current_company ||= Company.find_by(tenant_name: session[:tenant_name])
  end

  def set_current_request_details
    return unless user_signed_in?

    Current.user = current_user
    Current.company = current_company
    Current.ip_address = request.remote_ip
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
