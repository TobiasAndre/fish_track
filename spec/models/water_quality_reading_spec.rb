require "rails_helper"

RSpec.describe WaterQualityReading, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:water_quality_reading) }
  end

  it "is valid with a pond, a date and at least one parameter" do
    expect(build(:water_quality_reading)).to be_valid
  end

  it "accepts every parameter together, with decimals" do
    reading = build(:water_quality_reading, ph: 7.85, nitrite: 0.125, ammonia: 0.25, alkalinity: 120.5, salinity: 3.5)

    expect(reading).to be_valid
    reading.save!
    expect(reading.reload).to have_attributes(ph: 7.85.to_d, nitrite: 0.125.to_d, ammonia: 0.25.to_d, alkalinity: 120.5.to_d, salinity: 3.5.to_d)
  end

  it "needs at least one parameter" do
    reading = build(:water_quality_reading, ph: nil)

    expect(reading).not_to be_valid
    expect(reading.errors[:base].first).to include("pelo menos um parâmetro")
  end

  it "accepts a reading with only one of the parameters" do
    expect(build(:water_quality_reading, ph: nil, salinity: 2.0)).to be_valid
  end

  it "requires a pond and a date" do
    expect(build(:water_quality_reading, pond: nil)).not_to be_valid
    expect(build(:water_quality_reading, measured_at: nil)).not_to be_valid
  end

  it "keeps pH between 0 and 14 and the other parameters non-negative" do
    expect(build(:water_quality_reading, ph: 14.5)).not_to be_valid
    expect(build(:water_quality_reading, ph: -1)).not_to be_valid
    expect(build(:water_quality_reading, ph: 14)).to be_valid
    expect(build(:water_quality_reading, ph: nil, nitrite: -0.1)).not_to be_valid
    expect(build(:water_quality_reading, ph: nil, ammonia: -0.1)).not_to be_valid
    expect(build(:water_quality_reading, ph: nil, alkalinity: -1)).not_to be_valid
    expect(build(:water_quality_reading, ph: nil, salinity: -1)).not_to be_valid
    expect(build(:water_quality_reading, ph: nil, nitrite: 0)).to be_valid
  end

  it "does not accept a date in the future" do
    reading = build(:water_quality_reading, measured_at: 2.days.from_now)

    expect(reading).not_to be_valid
    expect(reading.errors[:measured_at]).to be_present
  end

  it "accepts a time later today (phone clocks and time zones)" do
    expect(build(:water_quality_reading, measured_at: Time.current.end_of_day - 1.minute)).to be_valid
  end

  describe ".latest_by_pond_id" do
    it "returns the most recent reading of each pond" do
      pond_a = create(:pond)
      pond_b = create(:pond)
      create(:water_quality_reading, pond: pond_a, measured_at: 3.days.ago, ph: 7.0)
      newest_a = create(:water_quality_reading, pond: pond_a, measured_at: 1.day.ago, ph: 7.5)
      only_b = create(:water_quality_reading, pond: pond_b, measured_at: 5.days.ago, ph: 6.8)

      latest = described_class.latest_by_pond_id

      expect(latest.keys).to contain_exactly(pond_a.id, pond_b.id)
      expect(latest[pond_a.id]).to eq(newest_a)
      expect(latest[pond_b.id]).to eq(only_b)
    end

    it "breaks a tie on the same instant by the latest record" do
      pond = create(:pond)
      at = 2.days.ago.change(sec: 0)
      create(:water_quality_reading, pond: pond, measured_at: at, ph: 7.0)
      later_id = create(:water_quality_reading, pond: pond, measured_at: at, ph: 7.9)

      expect(described_class.latest_by_pond_id[pond.id]).to eq(later_id)
    end
  end

  describe ".measured_between" do
    it "includes the whole first and last day" do
      pond = create(:pond)
      inside_start = create(:water_quality_reading, pond: pond, measured_at: Time.zone.parse("2026-09-01 00:05"))
      inside_end = create(:water_quality_reading, pond: pond, measured_at: Time.zone.parse("2026-09-05 23:50"))
      create(:water_quality_reading, pond: pond, measured_at: Time.zone.parse("2026-08-31 23:50"))
      create(:water_quality_reading, pond: pond, measured_at: Time.zone.parse("2026-09-06 00:05"))

      result = described_class.measured_between(Date.new(2026, 9, 1), Date.new(2026, 9, 5))

      expect(result).to contain_exactly(inside_start, inside_end)
    end
  end

  it "is removed with its pond" do
    reading = create(:water_quality_reading)

    expect { reading.pond.destroy }.to change(described_class, :count).by(-1)
  end
end
