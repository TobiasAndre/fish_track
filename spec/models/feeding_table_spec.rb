require "rails_helper"

RSpec.describe FeedingTable, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:feeding_table) }
  end

  it "is valid with a name" do
    expect(build(:feeding_table)).to be_valid
  end

  it "is invalid without a name" do
    feeding_table = build(:feeding_table, name: nil)

    expect(feeding_table).not_to be_valid
    expect(feeding_table.errors[:name]).to be_present
  end

  it "destroys its feeding strategy items when destroyed" do
    feeding_table = create(:feeding_table)
    create(:feeding_strategy_item, feeding_table: feeding_table)

    expect { feeding_table.destroy }.to change(FeedingStrategyItem, :count).by(-1)
  end
end
