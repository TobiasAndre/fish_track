require "rails_helper"

RSpec.describe Company, type: :model do
  it "is valid with a name and a well-formed tenant_name" do
    expect(build(:company)).to be_valid
  end

  it "is invalid without a name" do
    company = build(:company, name: nil)

    expect(company).not_to be_valid
    expect(company.errors[:name]).to be_present
  end

  it "is invalid without a tenant_name" do
    company = build(:company, tenant_name: nil)

    expect(company).not_to be_valid
    expect(company.errors[:tenant_name]).to be_present
  end

  it "is invalid with a tenant_name containing uppercase letters or spaces" do
    company = build(:company, tenant_name: "Not Valid")

    expect(company).not_to be_valid
    expect(company.errors[:tenant_name]).to be_present
  end

  it "is invalid with a duplicate tenant_name" do
    create(:company, tenant_name: "acme")
    company = build(:company, tenant_name: "acme")

    expect(company).not_to be_valid
    expect(company.errors[:tenant_name]).to be_present
  end

  it "destroys its memberships when destroyed" do
    company = create(:company)
    create(:membership, company: company)

    expect { company.destroy }.to change(Membership, :count).by(-1)
  end
end
