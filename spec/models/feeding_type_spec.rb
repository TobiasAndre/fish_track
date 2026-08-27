require "rails_helper"

RSpec.describe FeedingType, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:feeding_type) }
  end

  it "is valid with a name and a feeding_brand" do
    expect(build(:feeding_type)).to be_valid
  end

  it "is invalid without a name" do
    feeding_type = build(:feeding_type, name: nil)

    expect(feeding_type).not_to be_valid
    expect(feeding_type.errors[:name]).to be_present
  end

  it "is invalid without a feeding_brand" do
    feeding_type = build(:feeding_type, feeding_brand: nil)

    expect(feeding_type).not_to be_valid
    expect(feeding_type.errors[:feeding_brand]).to be_present
  end

  it "is invalid when the name only differs by case within the same brand" do
    brand = create(:feeding_brand)
    create(:feeding_type, feeding_brand: brand, name: "Extrusada 32%")

    duplicate = build(:feeding_type, feeding_brand: brand, name: "extrusada 32%")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "is invalid when the name only differs by surrounding whitespace within the same brand" do
    brand = create(:feeding_brand)
    create(:feeding_type, feeding_brand: brand, name: "Extrusada 32%")

    duplicate = build(:feeding_type, feeding_brand: brand, name: "  Extrusada 32%  ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "allows the same type name to be used under different brands" do
    create(:feeding_type, feeding_brand: create(:feeding_brand, name: "Guabi"), name: "Extrusada 32%")

    other_brand_type = build(:feeding_type, feeding_brand: create(:feeding_brand, name: "Purina"), name: "Extrusada 32%")

    expect(other_brand_type).to be_valid
  end

  it "allows updating a record without tripping its own uniqueness check" do
    feeding_type = create(:feeding_type, name: "Extrusada 32%")

    expect(feeding_type.update(name: "Extrusada 32%")).to be true
  end

  it "prevents destroying a feeding type still referenced by a silo stock entry" do
    feeding_type = create(:feeding_type)
    create(:silo_stock_entry, feeding_type: feeding_type)

    expect(feeding_type.destroy).to be false
    expect(FeedingType.exists?(feeding_type.id)).to be true
  end

  it "prevents destroying a feeding type still referenced by a stocking event" do
    feeding_type = create(:feeding_type)
    create(:stocking_event, :feeding, feeding_type: feeding_type)

    expect(feeding_type.destroy).to be false
    expect(FeedingType.exists?(feeding_type.id)).to be true
  end
end
