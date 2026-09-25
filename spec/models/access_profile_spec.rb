require "rails_helper"

RSpec.describe AccessProfile, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:access_profile) }
  end

  it "is valid with a name" do
    expect(build(:access_profile)).to be_valid
  end

  it "requires a name of at most 60 characters" do
    expect(build(:access_profile, name: "")).not_to be_valid
    expect(build(:access_profile, name: "a" * 61)).not_to be_valid
    expect(build(:access_profile, name: "a" * 60)).to be_valid
  end

  it "keeps names unique, ignoring case" do
    create(:access_profile, name: "Técnico")

    duplicate = build(:access_profile, name: "técnico")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  describe "#permission_matrix=" do
    it "grants the informed actions per page" do
      profile = create(:access_profile, permission_matrix: { "units" => %w[read write], "biometry_events" => %w[read edit delete] })

      expect(profile.reload.permission_map).to eq("units" => %w[read write], "biometry_events" => %w[read edit delete])
      expect(profile.granted?("units", "write")).to be(true)
      expect(profile.granted?("units", "edit")).to be(false)
      expect(profile.permissions_count).to eq(5)
    end

    it "adds read whenever write, edit or delete is granted" do
      profile = create(:access_profile, permission_matrix: { "ponds" => %w[delete], "silos" => %w[write edit] })

      expect(profile.reload.permission_map["ponds"]).to contain_exactly("read", "delete")
      expect(profile.permission_map["silos"]).to contain_exactly("read", "write", "edit")
    end

    it "ignores pages and actions the catalog doesn't know, and actions a page doesn't have" do
      profile = create(:access_profile, permission_matrix: {
        "units" => %w[read fly], "nope" => %w[read], "dashboard" => %w[read delete], "batch_reports" => %w[write]
      })

      expect(profile.reload.permission_map).to eq("units" => %w[read], "dashboard" => %w[read])
    end

    it "ignores non-list values, like the form's submitted marker" do
      profile = create(:access_profile, permission_matrix: { "__submitted" => "1", "units" => "read" })

      expect(profile.reload.permissions).to be_empty
    end

    it "syncs on update: keeps, adds and removes permissions" do
      profile = create(:access_profile, permission_matrix: { "units" => %w[read write], "ponds" => %w[read] })
      kept = profile.permissions.find { |p| p.resource == "units" && p.action == "read" }

      profile.update!(permission_matrix: { "units" => %w[read edit], "silos" => %w[read] })

      profile.reload
      expect(profile.permission_map).to eq("units" => %w[read edit], "silos" => %w[read])
      expect(AccessProfilePermission.exists?(kept.id)).to be(true)
    end

    it "clears everything when nothing is granted" do
      profile = create(:access_profile, permission_matrix: { "units" => %w[read] })

      profile.update!(permission_matrix: {})

      expect(profile.reload.permissions).to be_empty
    end

    it "doesn't touch permissions when it is not assigned" do
      profile = create(:access_profile, permission_matrix: { "units" => %w[read] })

      profile.update!(name: "Novo nome")

      expect(profile.reload.permission_map).to eq("units" => %w[read])
    end

    it "does not persist a change when the profile is invalid" do
      profile = create(:access_profile, permission_matrix: { "units" => %w[read write] })

      expect(profile.update(name: "", permission_matrix: { "ponds" => %w[read] })).to be(false)

      expect(profile.reload.permission_map).to eq("units" => %w[read write])
    end
  end

  it "removes its permissions with it" do
    profile = create(:access_profile, permission_matrix: { "units" => %w[read write] })

    expect { profile.destroy }.to change(AccessProfilePermission, :count).by(-2)
  end

  it "orders profiles by name, ignoring case" do
    create(:access_profile, name: "beta")
    create(:access_profile, name: "Alfa")
    create(:access_profile, name: "Charlie")

    expect(described_class.ordered.map(&:name)).to eq(%w[Alfa beta Charlie])
  end
end

RSpec.describe AccessProfilePermission, type: :model do
  it "rejects a page/action pair the catalog doesn't allow" do
    profile = create(:access_profile)

    expect(profile.permissions.build(resource: "dashboard", action: "delete")).not_to be_valid
    expect(profile.permissions.build(resource: "nope", action: "read")).not_to be_valid
    expect(profile.permissions.build(resource: "units", action: "read")).to be_valid
  end

  it "does not allow the same permission twice in a profile" do
    profile = create(:access_profile)
    profile.permissions.create!(resource: "units", action: "read")

    expect(profile.permissions.build(resource: "units", action: "read")).not_to be_valid
  end
end
