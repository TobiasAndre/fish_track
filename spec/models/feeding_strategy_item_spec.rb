require "rails_helper"

RSpec.describe FeedingStrategyItem, type: :model do
  it "is valid with a table, a weight range, a temperature range and a feeding percentage" do
    expect(build(:feeding_strategy_item)).to be_valid
  end

  it "is invalid without a feeding_percentage" do
    item = build(:feeding_strategy_item, feeding_percentage: nil)

    expect(item).not_to be_valid
    expect(item.errors[:feeding_percentage]).to be_present
  end

  it "is invalid when the table/weight-range/temperature-range combination is duplicated" do
    feeding_table = create(:feeding_table)
    weight_range = create(:feeding_weight_range)
    temperature_range = create(:feeding_temperature_range)

    create(:feeding_strategy_item,
      feeding_table: feeding_table,
      feeding_weight_range: weight_range,
      feeding_temperature_range: temperature_range)

    duplicate = build(:feeding_strategy_item,
      feeding_table: feeding_table,
      feeding_weight_range: weight_range,
      feeding_temperature_range: temperature_range)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
