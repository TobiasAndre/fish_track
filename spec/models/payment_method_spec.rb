require "rails_helper"

RSpec.describe PaymentMethod, type: :model do
  it "is valid with a name" do
    expect(build(:payment_method)).to be_valid
  end

  it "is invalid without a name" do
    payment_method = build(:payment_method, name: nil)

    expect(payment_method).not_to be_valid
    expect(payment_method.errors[:name]).to be_present
  end

  it "is invalid with a duplicate name" do
    create(:payment_method, name: "Pix")
    payment_method = build(:payment_method, name: "Pix")

    expect(payment_method).not_to be_valid
    expect(payment_method.errors[:name]).to be_present
  end

  it "is invalid with a nil active flag" do
    payment_method = build(:payment_method, active: nil)

    expect(payment_method).not_to be_valid
    expect(payment_method.errors[:active]).to be_present
  end
end
