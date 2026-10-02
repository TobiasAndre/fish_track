require "rails_helper"

RSpec.describe BackupSetting, type: :model do
  def connected_setting(**attrs)
    BackupSetting.create!(google_client_id: "client", google_client_secret: "secret", google_refresh_token: "refresh", **attrs)
  end

  describe "#next_run_after" do
    # Quinta-feira, 01/10/2026 10:00 (Brasília)
    let(:now) { Time.zone.local(2026, 10, 1, 10, 0) }

    it "runs daily at the chosen time: today if still ahead, otherwise tomorrow" do
      expect(described_class.new(frequency: "daily", time_of_day: "22:30").next_run_after(now)).to eq(Time.zone.local(2026, 10, 1, 22, 30))
      expect(described_class.new(frequency: "daily", time_of_day: "03:00").next_run_after(now)).to eq(Time.zone.local(2026, 10, 2, 3, 0))
      expect(described_class.new(frequency: "daily", time_of_day: "10:00").next_run_after(now)).to eq(Time.zone.local(2026, 10, 2, 10, 0))
    end

    it "runs weekly on the chosen weekday" do
      monday = described_class.new(frequency: "weekly", weekday: 1, time_of_day: "03:00")
      thursday_late = described_class.new(frequency: "weekly", weekday: 4, time_of_day: "23:00")
      thursday_early = described_class.new(frequency: "weekly", weekday: 4, time_of_day: "03:00")

      expect(monday.next_run_after(now)).to eq(Time.zone.local(2026, 10, 5, 3, 0))
      expect(thursday_late.next_run_after(now)).to eq(Time.zone.local(2026, 10, 1, 23, 0))
      expect(thursday_early.next_run_after(now)).to eq(Time.zone.local(2026, 10, 8, 3, 0))
    end

    it "runs monthly on the chosen day, moving to the next month once it has passed" do
      expect(described_class.new(frequency: "monthly", month_day: 15, time_of_day: "03:00").next_run_after(now))
        .to eq(Time.zone.local(2026, 10, 15, 3, 0))
      expect(described_class.new(frequency: "monthly", month_day: 1, time_of_day: "03:00").next_run_after(now))
        .to eq(Time.zone.local(2026, 11, 1, 3, 0))
      expect(described_class.new(frequency: "monthly", month_day: 28, time_of_day: "03:00").next_run_after(Time.zone.local(2026, 12, 29)))
        .to eq(Time.zone.local(2027, 1, 28, 3, 0))
    end
  end

  it "schedules the next run when automatic backup is turned on, and clears it when turned off" do
    setting = connected_setting

    setting.update!(schedule_enabled: true, frequency: "daily", time_of_day: "03:00")
    expect(setting.next_run_at).to eq(setting.next_run_after(setting.updated_at))

    setting.update!(schedule_enabled: false)
    expect(setting.next_run_at).to be_nil
  end

  it "cannot turn on automatic backup without a connected Google Drive" do
    setting = described_class.create!

    expect(setting.update(schedule_enabled: true)).to be(false)
    expect(setting.errors[:schedule_enabled]).to be_present
  end

  it "validates the time, the weekday and the day of month" do
    setting = described_class.new(time_of_day: "25:00", weekday: 7, month_day: 31, frequency: "hourly")

    expect(setting).not_to be_valid
    expect(setting.errors.attribute_names).to include(:time_of_day, :weekday, :month_day, :frequency)
  end

  it "drops the Google authorization (and the schedule) when the client ID changes" do
    setting = connected_setting(google_account_email: "a@example.com", drive_folder_id: "folder", schedule_enabled: true)

    setting.update!(google_client_id: "other-client")

    expect(setting.reload).to have_attributes(google_refresh_token: nil, google_account_email: nil, drive_folder_id: nil, schedule_enabled: false)
  end

  it "forgets the Drive folder id when the folder name changes" do
    setting = connected_setting(drive_folder_id: "folder")

    setting.update!(drive_folder_name: "Outra pasta")

    expect(setting.reload.drive_folder_id).to be_nil
  end

  it "stores the client secret and the refresh token encrypted" do
    setting = connected_setting

    raw = described_class.connection.select_one("SELECT google_client_secret, google_refresh_token FROM backup_settings WHERE id = #{setting.id}")
    expect(raw.values).to all(be_present)
    expect(raw.values).not_to include("secret", "refresh")
    expect(setting.reload.google_refresh_token).to eq("refresh")
  end

  describe "#claim_run!" do
    it "lets only one caller take a due run and moves the schedule forward" do
      setting = connected_setting(schedule_enabled: true)
      setting.update_column(:next_run_at, 1.minute.ago)
      other_process_copy = described_class.find(setting.id)

      expect(setting.due?).to be(true)
      expect(setting.claim_run!).to be(true)
      expect(other_process_copy.claim_run!).to be(false)
      expect(setting.reload.next_run_at).to be > Time.current
    end
  end
end
