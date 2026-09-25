class AccessProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_company!
  before_action :require_system_admin!
  before_action :set_profile, only: %i[edit update destroy]

  def index
    @profiles = AccessProfile.includes(:permissions).ordered
  end

  def new
    @profile = AccessProfile.new
  end

  def create
    @profile = AccessProfile.new(profile_params)

    if @profile.save
      redirect_to access_profiles_path, notice: "Perfil criado com sucesso."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @profile.update(profile_params)
      redirect_to access_profiles_path, notice: "Perfil atualizado com sucesso."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @profile.destroy
    redirect_to access_profiles_path, notice: "Perfil removido com sucesso."
  end

  private

  # Perfis vivem no schema da empresa: sem empresa selecionada não há onde gravar.
  def require_company!
    return if session[:tenant_name].present?

    redirect_to select_company_path, alert: "Selecione uma empresa para continuar."
  end

  # Por enquanto só o administrador do sistema gerencia perfis de acesso.
  def require_system_admin!
    return if system_admin?

    redirect_to root_path, alert: "Você não tem permissão para acessar esta área."
  end

  def set_profile
    @profile = AccessProfile.includes(:permissions).find(params[:id])
  end

  # A matriz vem como { "units" => ["read", "edit"], "__submitted" => "1" }; o
  # model descarta tudo que o catálogo não conhece. O marcador garante que
  # desmarcar todas as caixas também limpe as permissões.
  def profile_params
    attrs = params.require(:access_profile).permit(:name, :description)
    matrix = params.dig(:access_profile, :permission_matrix)
    attrs[:permission_matrix] = matrix.permit!.to_h if matrix.respond_to?(:permit!)
    attrs
  end
end
