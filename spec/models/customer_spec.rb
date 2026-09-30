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

  describe "#full_address" do
    it "joins street, number, complement, neighborhood, city/state and postal code" do
      customer = build(
        :customer,
        address: "Rua das Flores", address_number: "123", address_complement: "Sala 2",
        neighborhood: "Centro", city: "Toledo", state: "PR", postal_code: "85900-000"
      )

      expect(customer.full_address).to eq("Rua das Flores, 123 - Sala 2, Centro, Toledo/PR, CEP 85900-000")
    end

    it "skips the blank parts" do
      customer = build(:customer, address: "Rua das Flores", address_number: "", city: "Toledo")

      expect(customer.full_address).to eq("Rua das Flores, Toledo")
    end

    it "is nil when no address was filled in" do
      expect(build(:customer).full_address).to be_nil
    end
  end

  it "destroys its integrateds when destroyed" do
    customer = create(:customer)
    create(:integrated, customer: customer)

    expect { customer.destroy }.to change(Integrated, :count).by(-1)
  end
end
