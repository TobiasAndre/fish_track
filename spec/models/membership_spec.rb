require "rails_helper"

RSpec.describe Membership, type: :model do
  it "is valid with a user, a company and a valid role" do
    expect(build(:membership)).to be_valid
  end

  it "is invalid without a role" do
    membership = build(:membership, role: nil)

    expect(membership).not_to be_valid
    expect(membership.errors[:role]).to be_present
  end

  it "is invalid with a role outside the allowed list" do
    membership = build(:membership, role: "superadmin")

    expect(membership).not_to be_valid
    expect(membership.errors[:role]).to be_present
  end

  it "is invalid when the user already belongs to the company" do
    user = create(:user)
    company = create(:company)
    create(:membership, user: user, company: company)

    membership = build(:membership, user: user, company: company)

    expect(membership).not_to be_valid
    expect(membership.errors[:user_id]).to be_present
  end
end
