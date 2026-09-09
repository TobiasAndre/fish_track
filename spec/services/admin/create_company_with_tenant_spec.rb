require "rails_helper"

RSpec.describe Admin::CreateCompanyWithTenant do
  let(:owner) { create(:user) }
  let(:company_params) { { name: "Nova Empresa", tenant_name: "nova_empresa" } }

  subject(:service) { described_class.new(company_params: company_params, owner_user_id: owner.id) }

  context "when the tenant is provisioned successfully" do
    before do
      allow(Apartment::Tenant).to receive(:create)
      allow(Apartment::Tenant).to receive(:switch).and_yield
      allow_any_instance_of(ActiveRecord::MigrationContext).to receive(:migrate)
    end

    it "creates the company, provisions the tenant and adds the owner membership" do
      company = nil

      expect { company = service.call }
        .to change(Company, :count).by(1)
        .and change(Membership, :count).by(1)

      expect(Apartment::Tenant).to have_received(:create).with("nova_empresa")
      expect(company.memberships.first).to have_attributes(user_id: owner.id, role: "owner")
    end
  end

  context "when tenant provisioning fails" do
    before do
      allow(Apartment::Tenant).to receive(:create).and_raise(StandardError, "schema boom")
    end

    it "rolls back the company and re-raises the error" do
      expect { service.call }.to raise_error(StandardError, "schema boom")

      expect(Company.where(tenant_name: "nova_empresa")).not_to exist
      expect(Membership.count).to eq(0)
    end
  end
end
