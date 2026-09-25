module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[edit update]
    before_action :load_membership_options, only: %i[new create edit update]

    def index
      @users = User.order(:name, :email)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        sync_memberships
        redirect_to admin_users_path, notice: "Usuário criado com sucesso."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      attrs = password_params_blank? ? user_params.except(:password, :password_confirmation) : user_params

      if @user.update(attrs)
        sync_memberships
        redirect_to admin_users_path, notice: "Usuário atualizado com sucesso."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    # Empresas do sistema e, de cada uma, os perfis de acesso (que vivem no schema dela).
    def load_membership_options
      @companies = Company.order(:name)
      @profiles_by_company = @companies.to_h do |company|
        [company.id, Apartment::Tenant.switch(company.tenant_name) { AccessProfile.ordered.to_a }]
      end
    end

    def sync_memberships
      return unless params[:memberships].respond_to?(:permit!)

      Admin::SyncUserMemberships.new(user: @user, params: params[:memberships].permit!.to_h.with_indifferent_access).call
    end

    def password_params_blank?
      user_params[:password].blank? && user_params[:password_confirmation].blank?
    end
  end
end
