module Admin
  class CompanySettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_company

    def edit; end

    def update
      if @company.update(company_params)
        redirect_to edit_admin_company_setting_path(@company), notice: "Configurações atualizadas com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_company
      @company = Company.find_by!(tenant_name: session[:tenant_name])
    end

    def company_params
      params.require(:company).permit(
        :logo_url,
        :print_message_line_1,
        :print_message_line_2
      )
    end
  end
end
