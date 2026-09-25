require "rails_helper"

RSpec.describe AccessPolicy do
  let(:company) { create(:company, tenant_name: "public") }
  let(:user) { create(:user) }

  def policy_for(role: nil, profile: nil, target_user: user, target_company: company)
    create(:membership, user: target_user, company: target_company, role: role, access_profile_id: profile&.id) if role
    described_class.for(user: target_user, company: target_company)
  end

  def profile_with(matrix)
    create(:access_profile, permission_matrix: matrix.merge("__submitted" => "1"))
  end

  describe ".required_action" do
    def required(controller, action, verb)
      described_class.required_action(controller, action, verb)
    end

    it "maps the standard CRUD actions" do
      expect(required("units", "index", "GET")).to eq("read")
      expect(required("units", "show", "GET")).to eq("read")
      expect(required("units", "new", "GET")).to eq("write")
      expect(required("units", "create", "POST")).to eq("write")
      expect(required("units", "edit", "GET")).to eq("edit")
      expect(required("units", "update", "PATCH")).to eq("edit")
      expect(required("units", "destroy", "DELETE")).to eq("delete")
    end

    it "falls back to the HTTP verb for custom actions" do
      expect(required("financial_entries", "settle", "PATCH")).to eq("edit")
      expect(required("payroll_items", "pay", "POST")).to eq("write")
      expect(required("batch_reports", "print", "GET")).to eq("read")
    end

    it "treats generating a share link of a report as a read" do
      expect(required("feeding_plans", "create_share", "POST")).to eq("read")
      expect(required("batch_reports", "create_share", "POST")).to eq("read")
      expect(required("loading_reports", "create_share", "POST")).to eq("read")
      expect(required("silo_stock_reports", "create_share", "POST")).to eq("read")
    end
  end

  describe ".public_action?" do
    it "recognizes the token-protected share endpoints" do
      expect(described_class.public_action?("share_pdf")).to be(true)
      expect(described_class.public_action?("share_termination_report")).to be(true)
      expect(described_class.public_action?("index")).to be(false)
    end
  end

  describe ".for" do
    it "gives the system administrator everything the catalog offers" do
      admin = create(:user, system_admin: true)
      policy = described_class.for(user: admin, company: company)

      expect(policy).to be_full_access
      expect(policy.can?("units", "delete")).to be(true)
      expect(policy.can?("batch_results", "write")).to be(false), "actions the page does not have stay unavailable"
    end

    it "gives owners and admins of the company everything" do
      %w[owner admin].each do |role|
        person = create(:user)
        policy = policy_for(role: role, target_user: person)

        expect(policy).to be_full_access
        expect(policy.can?("financial_entries", "delete")).to be(true)
      end
    end

    it "gives a member only what the profile grants" do
      profile = profile_with("units" => %w[read write], "ponds" => %w[read])
      policy = policy_for(role: "member", profile: profile)

      expect(policy).not_to be_full_access
      expect(policy.can?("units", "read")).to be(true)
      expect(policy.can?("units", "write")).to be(true)
      expect(policy.can?("units", "edit")).to be(false)
      expect(policy.can?("units", "delete")).to be(false)
      expect(policy.can?("ponds", "read")).to be(true)
      expect(policy.can?("ponds", "write")).to be(false)
      expect(policy.can?("silos", "read")).to be(false)
    end

    it "gives a member without a profile nothing" do
      policy = policy_for(role: "member")

      expect(policy.can?("units", "read")).to be(false)
      expect(policy.first_readable_resource).to be_nil
    end

    it "gives nothing when the profile no longer exists (fails closed)" do
      create(:membership, user: user, company: company, role: "member", access_profile_id: 987_654)

      expect(described_class.for(user: user, company: company).can?("units", "read")).to be(false)
    end

    it "gives nothing to a user with no membership in the company" do
      expect(described_class.for(user: user, company: company).can?("units", "read")).to be(false)
    end

    it "gives nothing when no company is selected, except to the system administrator" do
      expect(described_class.for(user: user, company: nil).can?("units", "read")).to be(false)
      expect(described_class.for(user: create(:user, system_admin: true), company: nil)).to be_full_access
    end
  end

  describe "#first_readable_resource" do
    it "returns the first page of the menu the profile can read, skipping the one given" do
      profile = profile_with("dashboard" => %w[read], "ponds" => %w[read], "silos" => %w[read])
      policy = policy_for(role: "member", profile: profile)

      expect(policy.first_readable_resource.key).to eq("dashboard")
      expect(policy.first_readable_resource(excluding: PermissionCatalog.find("dashboard")).key).to eq("ponds")
    end
  end
end
