require "rails_helper"

RSpec.describe FeedingBrand, type: :model do
  it "is valid with a name" do
    expect(build(:feeding_brand)).to be_valid
  end

  it "is invalid without a name" do
    feeding_brand = build(:feeding_brand, name: nil)

    expect(feeding_brand).not_to be_valid
    expect(feeding_brand.errors[:name]).to be_present
  end

  it "is invalid when the name only differs by case" do
    create(:feeding_brand, name: "Guabi")

    duplicate = build(:feeding_brand, name: "guabi")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "is invalid when the name only differs by surrounding whitespace" do
    create(:feeding_brand, name: "Guabi")

    duplicate = build(:feeding_brand, name: "  Guabi  ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "prevents destroying a feeding brand still referenced by a feeding type" do
    feeding_brand = create(:feeding_brand)
    create(:feeding_type, feeding_brand: feeding_brand)

    expect(feeding_brand.destroy).to be false
    expect(FeedingBrand.exists?(feeding_brand.id)).to be true
  end

  it "prevents destroying a feeding brand still referenced by a stocking event" do
    feeding_brand = create(:feeding_brand)
    feeding_type = create(:feeding_type, feeding_brand: feeding_brand)
    create(:stocking_event, :feeding, feeding_type: feeding_type)

    expect(feeding_brand.destroy).to be false
    expect(FeedingBrand.exists?(feeding_brand.id)).to be true
  end
end
