require "rails_helper"

RSpec.describe "Loggable object snapshots" do
  let(:actor) { create(:user) }

  before { Current.user = actor }
  after { Current.reset }

  def last_log
    ActivityLog.order(:id).last
  end

  it "records no 'before' and the full record as 'after' on create" do
    unit = create(:unit, name: "Sede")

    log = last_log
    expect(log).to have_attributes(action: "create", resource_type: "Unit", resource_id: unit.id, object_before: nil)
    expect(log.object_after).to include("id" => unit.id, "name" => "Sede")
    expect(log.object_after.keys).to include("created_at", "updated_at")
  end

  it "records the previous and the new state on update" do
    unit = create(:unit, name: "Sede")

    unit.update!(name: "Sede Nova")

    log = last_log
    expect(log.action).to eq("update")
    expect(log.object_before["name"]).to eq("Sede")
    expect(log.object_after["name"]).to eq("Sede Nova")
    expect(log.object_before["id"]).to eq(log.object_after["id"])
  end

  it "keeps the untouched attributes identical in both snapshots" do
    pond = create(:pond, name: "Tanque 1", order_number: 4)

    pond.update!(name: "Tanque 2")

    log = last_log
    expect(log.object_before["order_number"]).to eq(4)
    expect(log.object_after["order_number"]).to eq(4)
    expect(log.field_changes.map(&:field)).to eq(["name"])
  end

  it "records the removed record as 'before' and nothing as 'after' on destroy" do
    unit = create(:unit, name: "Sede")

    unit.destroy

    log = last_log
    expect(log.action).to eq("destroy")
    expect(log.object_before).to include("id" => unit.id, "name" => "Sede")
    expect(log.object_after).to be_nil
  end

  it "stores JSON-safe values (dates, decimals) so they survive the round trip" do
    entry = create(:financial_entry, amount_cents: 12_345, occurred_on: Date.new(2026, 9, 25))

    log = ActivityLog.find(last_log.id)
    expect(log.object_after).to include("amount_cents" => 12_345, "occurred_on" => "2026-09-25", "description" => entry.description)
  end

  it "never stores passwords or tokens" do
    user = create(:user, password: "s3cret-Password!", password_confirmation: "s3cret-Password!")

    user.update!(name: "Novo Nome")

    log = last_log
    [log.object_before, log.object_after].each do |snapshot|
      expect(snapshot["encrypted_password"]).to eq(Loggable::FILTERED)
      expect(snapshot.to_json).not_to include("s3cret-Password!")
      expect(snapshot.to_json).not_to include(user.encrypted_password)
    end
    expect(log.field_changes.map(&:field)).to eq(["name"])
  end

  it "filters share tokens too" do
    event = create(:stocking_event, :loading)
    event.regenerate_share_token

    snapshot = ActivityLog.where(resource_type: "StockingEvent").order(:id).last.object_after
    expect(snapshot["share_token"]).to eq(Loggable::FILTERED)
  end

  it "leaves nil sensitive values as nil (nothing to hide)" do
    user = create(:user)

    expect(ActivityLog.where(resource_type: "User").order(:id).last.object_after["reset_password_token"]).to be_nil
  end

  it "does not log anything without a signed-in user, as before" do
    Current.user = nil

    expect { create(:unit) }.not_to change(ActivityLog, :count)
  end
end
