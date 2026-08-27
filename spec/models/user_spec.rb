require "rails_helper"

RSpec.describe User, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:user) }
  end

  it "is valid with an email and a password" do
    expect(build(:user)).to be_valid
  end

  it "is invalid without an email" do
    user = build(:user, email: nil)

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "is invalid with a duplicate email" do
    create(:user, email: "duplicate@example.com")
    user = build(:user, email: "duplicate@example.com")

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "is invalid when the password confirmation does not match" do
    user = build(:user, password: "password123", password_confirmation: "something-else")

    expect(user).not_to be_valid
    expect(user.errors[:password_confirmation]).to be_present
  end

  it "gains access to a company through a membership" do
    user = create(:user)
    company = create(:company)
    create(:membership, user: user, company: company)

    expect(user.companies).to include(company)
  end
end
