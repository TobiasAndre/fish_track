require "rails_helper"

RSpec.describe Product, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:product) }
  end

  it "is valid with a name and a unit from the allowed list" do
    expect(build(:product)).to be_valid
  end

  it "is invalid without a name" do
    product = build(:product, name: nil)

    expect(product).not_to be_valid
    expect(product.errors[:name]).to be_present
  end

  it "is invalid with a unit outside the allowed list" do
    product = build(:product, unit: "toneladas")

    expect(product).not_to be_valid
    expect(product.errors[:unit]).to be_present
  end

  it "is invalid with a duplicate sku" do
    create(:product, sku: "ABC-1")
    product = build(:product, sku: "ABC-1")

    expect(product).not_to be_valid
    expect(product.errors[:sku]).to be_present
  end

  it "allows a blank sku" do
    product = build(:product, sku: nil)

    expect(product).to be_valid
  end
end
