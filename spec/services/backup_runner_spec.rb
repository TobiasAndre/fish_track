require "rails_helper"

RSpec.describe BackupRunner do
  let(:setting) do
    BackupSetting.create!(google_client_id: "client", google_client_secret: "secret", google_refresh_token: "refresh",
      drive_folder_name: "Backups")
  end
  let(:backup) { Backup.create!(trigger: "manual") }
  let(:drive) { instance_double(GoogleDrive) }
  let(:generator) do
    Class.new do
      def create_file(dir)
        File.join(dir, "fish_track-backup-2026-10-02-030000.sql.gz").tap { |path| File.binwrite(path, "x" * 2048) }
      end
    end.new
  end

  before { allow(setting).to receive(:drive_client).and_return(drive) }

  it "generates the file, uploads it to the Drive folder and records the result" do
    allow(drive).to receive(:ensure_folder).with(id: nil, name: "Backups").and_return("folder-1")
    allow(drive).to receive(:upload)
      .with(an_instance_of(String), name: "fish_track-backup-2026-10-02-030000.sql.gz", folder_id: "folder-1")
      .and_return(id: "file-1", url: "https://drive.google.com/file/d/file-1/view")

    described_class.new(backup, setting: setting, generator: generator).call

    expect(backup.reload).to have_attributes(
      status: "succeeded", filename: "fish_track-backup-2026-10-02-030000.sql.gz", size_bytes: 2048,
      drive_file_id: "file-1", drive_file_url: "https://drive.google.com/file/d/file-1/view", error_message: nil
    )
    expect(backup.started_at).to be_present
    expect(backup.finished_at).to be_present
    expect(setting.reload.drive_folder_id).to eq("folder-1")
  end

  it "records the error when the upload fails" do
    allow(drive).to receive(:ensure_folder).and_return("folder-1")
    allow(drive).to receive(:upload).and_raise(GoogleDrive::Error, "Google Drive respondeu 403: quota")

    described_class.new(backup, setting: setting, generator: generator).call

    expect(backup.reload).to have_attributes(status: "failed", error_message: "Google Drive respondeu 403: quota")
    expect(backup.finished_at).to be_present
  end

  it "fails right away when the Google Drive is not connected" do
    setting.update!(google_refresh_token: nil)

    described_class.new(backup, setting: setting, generator: generator).call

    expect(backup.reload).to have_attributes(status: "failed", error_message: "O Google Drive não está conectado.")
  end
end
