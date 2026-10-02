require "tmpdir"

# Executa um Backup: gera o arquivo do banco e envia para a pasta configurada no
# Google Drive. Sucesso ou erro ficam gravados no próprio registro, que é o que
# a página Backup mostra no histórico.
class BackupRunner
  def initialize(backup, setting: BackupSetting.current, generator: DatabaseBackup.new)
    @backup = backup
    @setting = setting
    @generator = generator
  end

  def call
    backup.update!(status: "running", started_at: Time.current)
    raise GoogleDrive::Error, "O Google Drive não está conectado." unless setting.drive_connected?

    Dir.mktmpdir("fish_track-backup") do |dir|
      path = generator.create_file(dir)
      drive = setting.drive_client

      folder_id = drive.ensure_folder(id: setting.drive_folder_id, name: setting.drive_folder_name)
      setting.update_column(:drive_folder_id, folder_id) if folder_id != setting.drive_folder_id

      file = drive.upload(path, name: File.basename(path), folder_id: folder_id)

      backup.update!(
        status: "succeeded", finished_at: Time.current, filename: File.basename(path), size_bytes: File.size(path),
        drive_file_id: file[:id], drive_file_url: file[:url], error_message: nil
      )
    end

    backup
  rescue StandardError => e
    Rails.logger.error("[backup] ##{backup.id} falhou: #{e.class}: #{e.message}")
    backup.update!(status: "failed", finished_at: Time.current, error_message: e.message.to_s.truncate(1000))
    backup
  end

  private

  attr_reader :backup, :setting, :generator
end
