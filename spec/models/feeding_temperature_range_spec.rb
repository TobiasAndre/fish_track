require "rails_helper"

RSpec.describe FeedingTemperatureRange, type: :model do
  it "is valid with temperature_from and temperature_to" do
    expect(build(:feeding_temperature_range)).to be_valid
  end

  it "is invalid without temperature_from" do
    range = build(:feeding_temperature_range, temperature_from: nil)

    expect(range).not_to be_valid
    expect(range.errors[:temperature_from]).to be_present
  end

  it "is invalid without temperature_to" do
    range = build(:feeding_temperature_range, temperature_to: nil)

    expect(range).not_to be_valid
    expect(range.errors[:temperature_to]).to be_present
  end

  it "restricts destruction when referenced by a feeding strategy item" do
    range = create(:feeding_temperature_range)
    create(:feeding_strategy_item, feeding_temperature_range: range)

    expect { range.destroy }.not_to change(FeedingTemperatureRange, :count)
    expect(range.errors[:base]).to be_present
  end
end
