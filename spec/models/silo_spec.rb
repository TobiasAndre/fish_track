require "rails_helper"

RSpec.describe Silo, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:silo) }
  end

  it "is valid with a unit and a name" do
    expect(build(:silo)).to be_valid
  end

  it "is invalid without a name" do
    silo = build(:silo, name: nil)

    expect(silo).not_to be_valid
    expect(silo.errors[:name]).to be_present
  end

  it "is invalid without a unit" do
    silo = build(:silo, unit: nil)

    expect(silo).not_to be_valid
    expect(silo.errors[:unit]).to be_present
  end

  it "is invalid when the name only differs by case within the same unit" do
    unit = create(:unit)
    create(:silo, unit: unit, name: "Silo 1")

    duplicate = build(:silo, unit: unit, name: "silo 1")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "is invalid when the name only differs by surrounding whitespace within the same unit" do
    unit = create(:unit)
    create(:silo, unit: unit, name: "Silo 1")

    duplicate = build(:silo, unit: unit, name: "  Silo 1  ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "allows the same silo name to be used under different units" do
    create(:silo, unit: create(:unit), name: "Silo 1")

    other_unit_silo = build(:silo, unit: create(:unit), name: "Silo 1")

    expect(other_unit_silo).to be_valid
  end

  it "allows updating a record without tripping its own uniqueness check" do
    silo = create(:silo, name: "Silo 1")

    expect(silo.update(name: "Silo 1")).to be true
  end

  it "prevents destroying a silo still referenced by a stock entry" do
    silo = create(:silo)
    create(:silo_stock_entry, silo: silo)

    expect(silo.destroy).to be false
    expect(Silo.exists?(silo.id)).to be true
  end
end
