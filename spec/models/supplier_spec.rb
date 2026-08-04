require "rails_helper"

RSpec.describe Supplier, type: :model do
  it "is valid with a name" do
    expect(build(:supplier)).to be_valid
  end

  it "is invalid without a name" do
    supplier = build(:supplier, name: nil)

    expect(supplier).not_to be_valid
    expect(supplier.errors[:name]).to be_present
  end
end
