require "rails_helper"

RSpec.describe Integrated, type: :model do
  it "is valid with a customer and a name" do
    expect(build(:integrated)).to be_valid
  end

  it "is invalid without a customer" do
    integrated = build(:integrated, customer: nil)

    expect(integrated).not_to be_valid
    expect(integrated.errors[:customer]).to be_present
  end

  it "is invalid without a name" do
    integrated = build(:integrated, name: nil)

    expect(integrated).not_to be_valid
    expect(integrated.errors[:name]).to be_present
  end
end
