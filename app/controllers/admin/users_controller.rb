module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[edit update]

    def index
      @users = User.order(:name, :email)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "Usuário criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if password_params_blank?
        if @user.update(user_params.except(:password, :password_confirmation))
          redirect_to admin_users_path, notice: "Usuário atualizado com sucesso."
        else
          render :edit, status: :unprocessable_entity
        end
      elsif @user.update(user_params)
        redirect_to admin_users_path, notice: "Usuário atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    def password_params_blank?
      user_params[:password].blank? && user_params[:password_confirmation].blank?
    end
  end
end
