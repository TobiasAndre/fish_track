module Admin
  # Conecta (OAuth) e desconecta a conta Google para onde vão os backups.
  class GoogleDriveConnectionsController < BaseController
    before_action :set_setting

    # Leva à tela de consentimento do Google. O `state` aleatório na sessão
    # garante que o retorno é desta mesma tentativa.
    def new
      return redirect_to(admin_backup_path, alert: "Salve o Client ID e o Client Secret antes de conectar.") unless @setting.google_app_configured?

      state = SecureRandom.urlsafe_base64(32)
      session[:google_drive_oauth_state] = state

      redirect_to GoogleDrive.authorization_url(client_id: @setting.google_client_id, redirect_uri: redirect_uri, state: state),
        allow_other_host: true
    end

    # Retorno do Google com o código de autorização.
    def callback
      expected_state = session.delete(:google_drive_oauth_state)

      unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(expected_state, params[:state].to_s)
        return redirect_to(admin_backup_path, alert: "Não foi possível confirmar a autorização do Google. Tente conectar de novo.")
      end

      if params[:error].present? || params[:code].blank?
        return redirect_to(admin_backup_path, alert: "A conta Google não foi conectada (autorização cancelada ou negada).")
      end

      drive = GoogleDrive.new(client_id: @setting.google_client_id, client_secret: @setting.google_client_secret)
      refresh_token = drive.exchange_code!(code: params[:code], redirect_uri: redirect_uri)
      email = drive.account_email

      @setting.update!(google_refresh_token: refresh_token, google_account_email: email, drive_folder_id: nil)
      redirect_to admin_backup_path, notice: "Google Drive conectado (#{email})."
    rescue GoogleDrive::Error, Faraday::Error => e
      redirect_to admin_backup_path, alert: "Não foi possível conectar o Google Drive: #{e.message}"
    end

    def destroy
      @setting.drive_client.revoke! if @setting.drive_connected?
      @setting.update!(google_refresh_token: nil, google_account_email: nil, drive_folder_id: nil, schedule_enabled: false)

      redirect_to admin_backup_path, notice: "Google Drive desconectado. O backup automático foi desativado."
    end

    private

    def set_setting
      @setting = BackupSetting.current
    end

    def redirect_uri
      callback_admin_google_drive_connection_url
    end
  end
end
