require "rails_helper"

RSpec.describe PaymentTerm, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:payment_term) }
  end

  it "is valid with a name" do
    expect(build(:payment_term)).to be_valid
  end

  it "is invalid without a name" do
    payment_term = build(:payment_term, name: nil)

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:name]).to be_present
  end

  it "is invalid with a duplicate name" do
    create(:payment_term, name: "30 dias")
    payment_term = build(:payment_term, name: "30 dias")

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:name]).to be_present
  end

  it "is invalid with a nil active flag" do
    payment_term = build(:payment_term, active: nil)

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:active]).to be_present
  end
end
