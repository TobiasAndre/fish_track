require "rails_helper"

RSpec.describe StockingEvent, type: :model do
  it "is valid with a batch_stocking, occurred_on and event_type" do
    expect(build(:stocking_event)).to be_valid
  end

  it "is invalid without an occurred_on" do
    event = build(:stocking_event, occurred_on: nil)

    expect(event).not_to be_valid
    expect(event.errors[:occurred_on]).to be_present
  end

  it "is invalid without a batch_stocking" do
    event = build(:stocking_event, batch_stocking: nil)

    expect(event).not_to be_valid
    expect(event.errors[:batch_stocking]).to be_present
  end

  describe "biometrics validations" do
    it "requires volume, quantity and total_weight_kg to be present and positive" do
      event = build(:stocking_event, :biometrics, volume: nil, quantity: nil, total_weight_kg: nil)

      expect(event).not_to be_valid
      expect(event.errors[:volume]).to be_present
      expect(event.errors[:quantity]).to be_present
      expect(event.errors[:total_weight_kg]).to be_present
    end

    it "does not apply those validations to a mortality event" do
      event = build(:stocking_event, :mortality, quantity: 10)

      expect(event).to be_valid
    end
  end

  describe "#normalize_numeric_fields" do
    it "parses pt-BR formatted decimals (dot thousands separator, comma decimal separator)" do
      event = build(:stocking_event, :mortality, total_weight_kg: "1.234,56")

      event.valid?

      expect(event.total_weight_kg).to eq(1234.56)
    end

    it "strips non-digit characters from integer fields" do
      event = build(:stocking_event, :mortality, quantity: "1.234")

      event.valid?

      expect(event.quantity).to eq(1234)
    end
  end

  describe "#calculate_biometry_fields" do
    it "derives avg_weight_g from quantity and total_weight_kg" do
      event = build(:stocking_event, :biometrics, quantity: 1000, total_weight_kg: 5.0, volume: 1000)

      event.valid?

      expect(event.avg_weight_g.to_f).to eq(5.0) # (5.0kg / 1000) * 1000g
    end

    it "derives biomass from volume and avg_weight_g" do
      event = build(:stocking_event, :biometrics, quantity: 1000, total_weight_kg: 5.0, volume: 800)

      event.valid?

      expect(event.biomass.to_f).to eq(4.0) # 800 * (5g / 1000)
    end

    it "computes weight_gain_kg and gpd relative to the previous biometry event" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0, stocked_on: 4.days.ago.to_date)

      new_event = build(:stocking_event, :biometrics,
        batch_stocking: batch_stocking,
        quantity: 1000,
        total_weight_kg: 6.0,
        volume: 1000,
        occurred_on: 2.days.ago.to_date)

      new_event.save!

      expect(new_event.weight_gain_kg.to_f).to eq(2.0) # 6.0kg biomass - 4.0kg previous biomass
      expect(new_event.gpd.to_f).to eq(1.0) # (6g - 4g) avg weight / 2 days
    end

    it "defaults weight_gain_kg and gpd to zero when there is no previous biometry" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0)
      batch_stocking.stocking_events.destroy_all # remove the auto-created initial biometry

      event = build(:stocking_event, :biometrics,
        batch_stocking: batch_stocking,
        quantity: 1000,
        total_weight_kg: 5.0,
        volume: 1000)

      event.valid?

      expect(event.weight_gain_kg.to_f).to eq(0.0)
      expect(event.gpd.to_f).to eq(0.0)
    end
  end

  describe "#calculate_loading_fields" do
    it "derives quantity from total_weight_kg and avg_weight_g, rounding up" do
      event = build(:stocking_event, :loading, total_weight_kg: 100, avg_weight_g: 300)

      event.valid?

      expect(event.quantity).to eq(334) # ceil((100 * 1000) / 300)
    end

    it "does not touch quantity for non-loading events" do
      event = build(:stocking_event, :mortality, quantity: 10, total_weight_kg: 100, avg_weight_g: 300)

      event.valid?

      expect(event.quantity).to eq(10)
    end
  end

  describe "event_type enum" do
    it "exposes predicate methods for each event type" do
      expect(build(:stocking_event, :mortality)).to be_mortality_event_type
      expect(build(:stocking_event, :biometrics)).to be_biometrics_event_type
      expect(build(:stocking_event, :loading)).to be_loading_event_type
    end
  end

  describe ".recent_first" do
    it "orders events by occurred_on and created_at descending" do
      batch_stocking = create(:batch_stocking)
      older = create(:stocking_event, :mortality, batch_stocking: batch_stocking, occurred_on: 5.days.ago.to_date)
      newer = create(:stocking_event, :mortality, batch_stocking: batch_stocking, occurred_on: 1.day.ago.to_date)

      mortality_ids = batch_stocking.stocking_events.where(event_type: "mortality").recent_first.pluck(:id)

      expect(mortality_ids).to eq([newer.id, older.id])
    end
  end
end
