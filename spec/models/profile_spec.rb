require "rails_helper"

RSpec.describe Profile, type: :model do
  it "is valid with a user_id" do
    expect(build(:profile)).to be_valid
  end

  it "is invalid without a user_id" do
    profile = build(:profile, user: nil)

    expect(profile).not_to be_valid
    expect(profile.errors[:user_id]).to be_present
  end

  it "is invalid with a duplicate user_id" do
    user = create(:user)
    create(:profile, user: user)

    profile = build(:profile, user: user)

    expect(profile).not_to be_valid
    expect(profile.errors[:user_id]).to be_present
  end
end
