require "rails_helper"

RSpec.describe BackupScheduler do
  let!(:setting) do
    BackupSetting.create!(google_client_id: "client", google_client_secret: "secret", google_refresh_token: "refresh",
      schedule_enabled: true, frequency: "daily", time_of_day: "03:00")
  end
  let(:runner) { instance_double(BackupRunner, call: nil) }

  before { allow(BackupRunner).to receive(:new).and_return(runner) }

  it "runs a scheduled backup once the time has come and schedules the next one" do
    setting.update_column(:next_run_at, 1.minute.ago)

    expect { described_class.new.tick }.to change { Backup.where(trigger: "scheduled").count }.by(1)

    expect(runner).to have_received(:call)
    expect(setting.reload.next_run_at).to be > Time.current
  end

  it "does nothing before the time" do
    setting.update_column(:next_run_at, 1.hour.from_now)

    expect { described_class.new.tick }.not_to change(Backup, :count)
  end

  it "does nothing when automatic backup is off" do
    setting.update!(schedule_enabled: false)
    setting.update_column(:next_run_at, 1.minute.ago)

    expect { described_class.new.tick }.not_to change(Backup, :count)
  end

  it "runs a missed backup only once when the server comes back" do
    setting.update_column(:next_run_at, 3.days.ago)

    2.times { described_class.new.tick }

    expect(Backup.count).to eq(1)
  end

  it "marks backups that never finished as failed" do
    stuck = Backup.create!(trigger: "manual", status: "running", created_at: 3.hours.ago)
    recent = Backup.create!(trigger: "manual", status: "running")

    described_class.new.tick

    expect(stuck.reload).to have_attributes(status: "failed")
    expect(recent.reload.status).to eq("running")
  end

  it "is off in tests and can be forced on or off by BACKUP_SCHEDULER" do
    expect(described_class.enabled?).to be(false)
  end
end
