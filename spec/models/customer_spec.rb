require "rails_helper"

RSpec.describe Customer, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:customer) }
  end

  it "is valid with a name" do
    expect(build(:customer)).to be_valid
  end

  it "is invalid without a name" do
    customer = build(:customer, name: nil)

    expect(customer).not_to be_valid
    expect(customer.errors[:name]).to be_present
  end

  it "destroys its integrateds when destroyed" do
    customer = create(:customer)
    create(:integrated, customer: customer)

    expect { customer.destroy }.to change(Integrated, :count).by(-1)
  end
end
