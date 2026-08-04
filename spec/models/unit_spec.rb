require "rails_helper"

RSpec.describe Unit, type: :model do
  it "is valid with a name" do
    expect(build(:unit)).to be_valid
  end

  it "is invalid without a name" do
    unit = build(:unit, name: nil)

    expect(unit).not_to be_valid
    expect(unit.errors[:name]).to be_present
  end

  it "destroys its ponds when destroyed" do
    unit = create(:unit)
    pond = create(:pond, unit: unit)

    expect { unit.destroy }.to change(Pond, :count).by(-1)
    expect { pond.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
