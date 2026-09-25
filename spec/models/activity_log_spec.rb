require "rails_helper"

RSpec.describe ActivityLog, "object snapshots" do
  let(:user) { create(:user) }

  def record(**attrs)
    described_class.record!(**{ user: user, action: "update", resource_type: "Pond", description: "Tanque X", company: nil, ip_address: "203.0.113.5" }.merge(attrs))
  end

  it "stores the before/after objects as JSON" do
    log = record(object_before: { "name" => "A", "order_number" => 1 }, object_after: { "name" => "B", "order_number" => 1 })

    log = described_class.find(log.id)
    expect(log.object_before).to eq("name" => "A", "order_number" => 1)
    expect(log.object_after).to eq("name" => "B", "order_number" => 1)
  end

  it "has no snapshot for logs recorded without objects (older logs)" do
    expect(record).not_to be_snapshot
    expect(record(object_after: { "a" => 1 })).to be_snapshot
  end

  describe "#field_changes" do
    it "lists only the fields that changed on update, ignoring updated_at" do
      log = record(object_before: { "name" => "A", "order_number" => 1, "updated_at" => "1" },
                   object_after: { "name" => "B", "order_number" => 1, "updated_at" => "2" })

      expect(log.field_changes.map { |c| [c.field, c.before, c.after] }).to eq([["name", "A", "B"]])
    end

    it "lists every stored field on create, with no 'before'" do
      log = record(action: "create", object_before: nil, object_after: { "name" => "B", "order_number" => 1 })

      expect(log.field_changes.map { |c| [c.field, c.before, c.after] }).to eq([["name", nil, "B"], ["order_number", nil, 1]])
    end

    it "lists every field that existed on destroy, with no 'after'" do
      log = record(action: "destroy", object_before: { "name" => "A" }, object_after: nil)

      expect(log.field_changes.map { |c| [c.field, c.before, c.after] }).to eq([["name", "A", nil]])
    end

    it "is empty when nothing changed and when there is no snapshot" do
      expect(record(object_before: { "a" => 1 }, object_after: { "a" => 1 }).field_changes).to be_empty
      expect(record.field_changes).to be_empty
    end

    it "keeps a field that was added or removed between the two states" do
      log = record(object_before: { "a" => 1 }, object_after: { "a" => 1, "b" => 2 })

      expect(log.field_changes.map(&:field)).to eq(["b"])
    end
  end
end
