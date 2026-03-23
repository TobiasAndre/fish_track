module Admin
  class CompanySettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_company

    def edit; end

    def update
      if params[:company][:logo_file].present?
        @company.logo_url = SquareBlobUploader.call(file: params[:company][:logo_file])
      end

      if @company.update(company_params)
        redirect_to edit_company_settings_path, notice: "Configurações atualizadas com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue SquareBlobUploader::UploadError => e
      @company.assign_attributes(company_params)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def set_company
      @company = Company.find_by!(tenant_name: session[:tenant_name])
    end

    def company_params
      params.require(:company).permit(
        :print_message_line_1,
        :print_message_line_2
      )
    end
  end
end
