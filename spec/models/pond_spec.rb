require "rails_helper"

RSpec.describe Pond, type: :model do
  it "is valid with a unit and a name" do
    expect(build(:pond)).to be_valid
  end

  it "is invalid without a unit" do
    pond = build(:pond, unit: nil)

    expect(pond).not_to be_valid
    expect(pond.errors[:unit]).to be_present
  end

  describe "#full_name" do
    it "joins the unit name and the pond name" do
      unit = build(:unit, name: "Unidade Norte")
      pond = build(:pond, unit: unit, name: "Tanque 1")

      expect(pond.full_name).to eq("Unidade Norte - Tanque 1")
    end

    it "falls back to just the pond name when there is no unit" do
      pond = build(:pond, unit: nil, name: "Tanque 1")

      expect(pond.full_name).to eq("Tanque 1")
    end
  end
end
