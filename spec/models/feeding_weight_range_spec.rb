require "rails_helper"

RSpec.describe FeedingWeightRange, type: :model do
  it "is valid with weight_from and weight_to" do
    expect(build(:feeding_weight_range)).to be_valid
  end

  it "is invalid without weight_from" do
    range = build(:feeding_weight_range, weight_from: nil)

    expect(range).not_to be_valid
    expect(range.errors[:weight_from]).to be_present
  end

  it "is invalid without weight_to" do
    range = build(:feeding_weight_range, weight_to: nil)

    expect(range).not_to be_valid
    expect(range.errors[:weight_to]).to be_present
  end

  it "restricts destruction when referenced by a feeding strategy item" do
    range = create(:feeding_weight_range)
    create(:feeding_strategy_item, feeding_weight_range: range)

    expect { range.destroy }.not_to change(FeedingWeightRange, :count)
    expect(range.errors[:base]).to be_present
  end
end
