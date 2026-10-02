require "tmpdir"

module Admin
  # Página Backup (só o administrador do sistema): destino no Google Drive,
  # agendamento automático, backup manual e histórico.
  class BackupsController < BaseController
    before_action :set_setting

    def show
      load_page
    end

    def update
      if @setting.update(setting_params)
        redirect_to admin_backup_path, notice: "Configuração de backup salva."
      else
        load_page
        render :show, status: :unprocessable_content
      end
    end

    # Gera o backup em background e envia ao Google Drive.
    def run
      return redirect_to(admin_backup_path, alert: "Conecte o Google Drive antes de enviar um backup.") unless @setting.drive_connected?
      return redirect_to(admin_backup_path, alert: "Já existe um backup em andamento.") if Backup.in_progress.exists?

      backup = Backup.create!(trigger: "manual", requested_by: current_user)
      BackupJob.perform_later(backup.id)
      log_backup_action("Backup manual enviado ao Google Drive")

      redirect_to admin_backup_path, notice: "Backup iniciado. Ele aparece no histórico assim que terminar."
    end

    # Gera o backup na hora e entrega o arquivo ao navegador (não passa pelo Drive).
    def download
      generator = DatabaseBackup.new

      Dir.mktmpdir("fish_track-backup") do |dir|
        path = generator.create_file(dir)
        log_backup_action("Backup baixado pelo navegador")
        send_data File.binread(path), filename: File.basename(path), type: "application/gzip", disposition: "attachment"
      end
    end

    private

    def set_setting
      @setting = BackupSetting.current
    end

    def load_page
      @backups = Backup.includes(:requested_by).recent_first.limit(20)
      @redirect_uri = callback_admin_google_drive_connection_url
    end

    # O client secret em branco mantém o já salvo (o campo nunca é preenchido de volta na tela).
    def setting_params
      permitted = params.require(:backup_setting).permit(
        :google_client_id, :google_client_secret, :drive_folder_name,
        :schedule_enabled, :frequency, :time_of_day, :weekday, :month_day
      )
      permitted.delete(:google_client_secret) if permitted[:google_client_secret].blank?
      permitted[:google_client_id] = permitted[:google_client_id].strip if permitted[:google_client_id]
      permitted
    end

    def log_backup_action(description)
      ActivityLog.record!(user: current_user, action: "create", resource_type: "Backup", description: description, company: nil)
    end
  end
end
