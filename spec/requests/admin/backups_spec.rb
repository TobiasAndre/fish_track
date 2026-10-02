require "rails_helper"

RSpec.describe "Admin::Backups", type: :request do
  let(:admin) { create(:user, system_admin: true) }
  let(:regular_user) { create(:user) }

  def connect_drive(**attrs)
    BackupSetting.current.update!(google_client_id: "client", google_client_secret: "secret", google_refresh_token: "refresh",
      google_account_email: "backup@example.com", **attrs)
  end

  describe "access" do
    it "is only for the system administrator" do
      sign_in regular_user

      get admin_backup_path
      expect(response).to redirect_to(root_path)

      post run_admin_backup_path
      expect(response).to redirect_to(root_path)

      get download_admin_backup_path
      expect(response).to redirect_to(root_path)

      get new_admin_google_drive_connection_path
      expect(response).to redirect_to(root_path)
    end

    it "shows the Backup entry in the menu only to the system administrator" do
      sign_in admin
      get admin_backup_path
      expect(Nokogiri::HTML(response.body).css("a[href='#{admin_backup_path}']")).to be_present
    end
  end

  context "as the system administrator" do
    before { sign_in admin }

    it "shows the setup steps with the redirect URI to register at Google" do
      get admin_backup_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Como criar o acesso ao Google Drive")
      expect(response.body).to include(callback_admin_google_drive_connection_url)
      expect(response.body).to include("Nenhum backup gerado ainda")
    end

    it "saves the Google app credentials, keeping the saved secret when the field is left blank" do
      patch admin_backup_path, params: { backup_setting: { google_client_id: " client-id ", google_client_secret: "s3cret", drive_folder_name: "Backups" } }
      expect(response).to redirect_to(admin_backup_path)

      patch admin_backup_path, params: { backup_setting: { google_client_id: "client-id", google_client_secret: "", drive_folder_name: "Backups" } }

      expect(BackupSetting.current).to have_attributes(google_client_id: "client-id", google_client_secret: "s3cret", drive_folder_name: "Backups")
      get admin_backup_path
      expect(response.body).not_to include("s3cret")
    end

    it "turns on the weekly schedule and shows the next run" do
      connect_drive

      patch admin_backup_path, params: { backup_setting: { schedule_enabled: "1", frequency: "weekly", weekday: "1", time_of_day: "02:30" } }
      follow_redirect!

      setting = BackupSetting.current
      expect(setting).to have_attributes(schedule_enabled: true, frequency: "weekly", weekday: 1, time_of_day: "02:30")
      expect(setting.next_run_at).to eq(setting.next_run_after(setting.updated_at))
      expect(response.body).to include("Semanal (Segunda-feira) às 02:30")
      expect(response.body).to include(I18n.l(setting.next_run_at, format: "%d/%m/%Y %H:%M"))
    end

    it "does not turn on the schedule without a connected Google Drive" do
      patch admin_backup_path, params: { backup_setting: { schedule_enabled: "1" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("precisa do Google Drive conectado")
      expect(BackupSetting.current.schedule_enabled).to be(false)
    end

    describe "POST run" do
      it "queues a manual backup to the Google Drive" do
        connect_drive

        expect { post run_admin_backup_path }.to change(Backup, :count).by(1)

        backup = Backup.last
        expect(backup).to have_attributes(trigger: "manual", status: "pending", requested_by: admin)
        expect(BackupJob).to have_been_enqueued.with(backup.id)
        expect(response).to redirect_to(admin_backup_path)
        expect(ActivityLog.last).to have_attributes(user: admin, resource_type: "Backup", description: "Backup manual enviado ao Google Drive")
      end

      it "refuses without a connected Google Drive" do
        expect { post run_admin_backup_path }.not_to change(Backup, :count)
        expect(flash[:alert]).to include("Conecte o Google Drive")
      end

      it "refuses while another backup is still running" do
        connect_drive
        Backup.create!(trigger: "scheduled", status: "running")

        expect { post run_admin_backup_path }.not_to change(Backup, :count)
        expect(flash[:alert]).to include("em andamento")
      end
    end

    it "downloads a fresh backup file" do
      create(:customer, name: "Cliente do Backup")

      get download_admin_backup_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/gzip")
      expect(response.headers["Content-Disposition"]).to match(/attachment; filename="fish_track-backup-.*\.sql\.gz"/)
      expect(Zlib.gunzip(response.body)).to include("Cliente do Backup")
    end

    it "lists the history with status, size, Drive link and error" do
      Backup.create!(trigger: "scheduled", status: "succeeded", filename: "fish_track-backup-a.sql.gz", size_bytes: 2048,
        drive_file_url: "https://drive.google.com/file/d/1/view")
      Backup.create!(trigger: "manual", status: "failed", error_message: "Google Drive respondeu 403: quota", requested_by: admin)

      get admin_backup_path

      expect(response.body).to include("Concluído", "Agendado", "2 KB", "https://drive.google.com/file/d/1/view")
      expect(response.body).to include("Falhou", "Google Drive respondeu 403: quota", admin.name)
    end
  end

  describe "Google Drive connection" do
    before { sign_in admin }

    it "asks for the Client ID and Secret before connecting" do
      get new_admin_google_drive_connection_path

      expect(response).to redirect_to(admin_backup_path)
    end

    it "sends the administrator to Google's consent screen with a one-time state" do
      BackupSetting.current.update!(google_client_id: "client", google_client_secret: "secret")

      get new_admin_google_drive_connection_path

      location = URI(response.location)
      query = Rack::Utils.parse_query(location.query)
      expect(location.host).to eq("accounts.google.com")
      expect(query).to include("client_id" => "client", "redirect_uri" => callback_admin_google_drive_connection_url)
      expect(query["state"]).to be_present
    end

    it "stores the refresh token and the account e-mail when Google sends the administrator back" do
      BackupSetting.current.update!(google_client_id: "client", google_client_secret: "secret")
      drive = instance_double(GoogleDrive, exchange_code!: "refresh-token", account_email: "backup@example.com")
      allow(GoogleDrive).to receive(:new).with(client_id: "client", client_secret: "secret").and_return(drive)

      get new_admin_google_drive_connection_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get callback_admin_google_drive_connection_path, params: { state: state, code: "the-code" }

      expect(drive).to have_received(:exchange_code!).with(code: "the-code", redirect_uri: callback_admin_google_drive_connection_url)
      expect(BackupSetting.current).to have_attributes(google_refresh_token: "refresh-token", google_account_email: "backup@example.com")
      expect(flash[:notice]).to include("backup@example.com")
    end

    it "rejects a callback whose state does not match" do
      BackupSetting.current.update!(google_client_id: "client", google_client_secret: "secret")
      allow(GoogleDrive).to receive(:new)

      get new_admin_google_drive_connection_path
      get callback_admin_google_drive_connection_path, params: { state: "forged", code: "the-code" }

      expect(GoogleDrive).not_to have_received(:new)
      expect(BackupSetting.current.google_refresh_token).to be_nil
      expect(flash[:alert]).to include("Não foi possível confirmar")
    end

    it "reports when the administrator denies access at Google" do
      BackupSetting.current.update!(google_client_id: "client", google_client_secret: "secret")

      get new_admin_google_drive_connection_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get callback_admin_google_drive_connection_path, params: { state: state, error: "access_denied" }

      expect(flash[:alert]).to include("não foi conectada")
    end

    it "disconnects, revoking the token and turning the schedule off" do
      connect_drive(schedule_enabled: true)
      drive = instance_double(GoogleDrive, revoke!: nil)
      allow_any_instance_of(BackupSetting).to receive(:drive_client).and_return(drive)

      delete admin_google_drive_connection_path

      expect(drive).to have_received(:revoke!)
      expect(BackupSetting.current).to have_attributes(google_refresh_token: nil, google_account_email: nil, schedule_enabled: false)
    end
  end
end
