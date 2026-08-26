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

  describe "feeding validations" do
    it "requires a feeding_type, feeding_brand and a positive feed_kg" do
      event = build(:stocking_event, :feeding, feeding_type: nil, feeding_brand: nil, feed_kg: 0)

      expect(event).not_to be_valid
      expect(event.errors[:feeding_type_id]).to be_present
      expect(event.errors[:feeding_brand_id]).to be_present
      expect(event.errors[:feed_kg]).to be_present
    end

    it "does not apply those validations to a mortality event" do
      event = build(:stocking_event, :mortality, quantity: 10)

      expect(event).to be_valid
    end

    it "rejects a negative total_cents" do
      event = build(:stocking_event, :feeding, total_cents: -1)

      expect(event).not_to be_valid
      expect(event.errors[:total_cents]).to be_present
    end

    it "accepts a zero total_cents (e.g. donated ration)" do
      event = build(:stocking_event, :feeding, total_cents: 0)

      expect(event).to be_valid
    end

    it "is invalid when the batch is closed" do
      batch_stocking = create(:batch_stocking)
      batch_stocking.batch.update!(status: "closed")

      event = build(:stocking_event, :feeding, batch_stocking: batch_stocking)

      expect(event).not_to be_valid
      expect(event.errors[:batch_stocking]).to be_present
    end
  end

  describe "#sync_feeding_brand_from_type" do
    it "derives feeding_brand from the selected feeding_type's brand" do
      brand = create(:feeding_brand, name: "Guabi")
      type = create(:feeding_type, name: "Extrusada 32%", feeding_brand: brand)

      event = create(:stocking_event, :feeding, feeding_type: type)

      expect(event.feeding_brand).to eq(brand)
    end

    it "ignores a manually assigned feeding_brand that does not match the feeding_type's brand" do
      correct_brand = create(:feeding_brand, name: "Guabi")
      other_brand = create(:feeding_brand, name: "Purina")
      type = create(:feeding_type, feeding_brand: correct_brand)

      event = create(:stocking_event, :feeding, feeding_type: type, feeding_brand: other_brand)

      expect(event.feeding_brand).to eq(correct_brand)
    end

    it "updates feeding_brand when the feeding_type is changed" do
      brand_a = create(:feeding_brand, name: "Guabi")
      brand_b = create(:feeding_brand, name: "Purina")
      type_a = create(:feeding_type, feeding_brand: brand_a)
      type_b = create(:feeding_type, feeding_brand: brand_b)

      event = create(:stocking_event, :feeding, feeding_type: type_a)
      expect(event.feeding_brand).to eq(brand_a)

      event.update!(feeding_type: type_b)
      expect(event.feeding_brand).to eq(brand_b)
    end
  end

  describe "#calculate_feeding_fields" do
    it "derives price_per_kg_cents from total_cents and feed_kg" do
      event = build(:stocking_event, :feeding, feed_kg: 50, total_cents: 25_000)

      event.valid?

      expect(event.price_per_kg_cents).to eq(500) # R$ 250,00 / 50kg = R$ 5,00/kg
    end

    it "recalculates price_per_kg_cents whenever feed_kg or total_cents change" do
      event = create(:stocking_event, :feeding, feed_kg: 50, total_cents: 25_000)
      expect(event.price_per_kg_cents).to eq(500)

      event.update!(feed_kg: 100)
      expect(event.price_per_kg_cents).to eq(250)

      event.update!(total_cents: 40_000)
      expect(event.price_per_kg_cents).to eq(400)
    end

    it "zeroes price_per_kg_cents when feed_kg is blank" do
      event = build(:stocking_event, :feeding, feed_kg: nil)

      event.valid?

      expect(event.price_per_kg_cents).to eq(0)
    end
  end

  describe "financial entries" do
    it "does not create a financial entry when a feeding event is created" do
      expect do
        create(:stocking_event, :feeding, feed_kg: 50, total_cents: 25_000)
      end.not_to change(FinancialEntry, :count)
    end

    it "does not respond to #financial_entry (the expense now lives on the silo stock entry)" do
      event = create(:stocking_event, :feeding, feed_kg: 50, total_cents: 25_000)

      expect(event).not_to respond_to(:financial_entry)
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
