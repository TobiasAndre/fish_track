require "rails_helper"

RSpec.describe BatchStocking, type: :model do
  it "is valid with a batch, pond, quantity and stocked_on" do
    expect(build(:batch_stocking)).to be_valid
  end

  it "is invalid without a quantity" do
    batch_stocking = build(:batch_stocking, quantity: nil)

    expect(batch_stocking).not_to be_valid
    expect(batch_stocking.errors[:quantity]).to be_present
  end

  it "is invalid with a zero quantity" do
    batch_stocking = build(:batch_stocking, quantity: 0)

    expect(batch_stocking).not_to be_valid
    expect(batch_stocking.errors[:quantity]).to be_present
  end

  it "is invalid without stocked_on" do
    batch_stocking = build(:batch_stocking, stocked_on: nil)

    expect(batch_stocking).not_to be_valid
    expect(batch_stocking.errors[:stocked_on]).to be_present
  end

  it "is invalid with a negative avg_weight_g" do
    batch_stocking = build(:batch_stocking, avg_weight_g: -1)

    expect(batch_stocking).not_to be_valid
    expect(batch_stocking.errors[:avg_weight_g]).to be_present
  end

  describe "#display_name" do
    it "combines the unit, batch and pond names" do
      unit = create(:unit, name: "Unidade Norte")
      pond = create(:pond, unit: unit, name: "Tanque 1")
      batch = create(:batch, name: "Lote 42", pond: pond)
      batch_stocking = batch.batch_stockings.first

      expect(batch_stocking.display_name).to eq("Unidade Norte • Lote: Lote 42 • Tanque: Tanque 1")
    end
  end

  describe "on create" do
    it "initializes current_quantity and current_biomass_kg from the stocked amounts" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0)

      expect(batch_stocking.current_quantity).to eq(1000)
      expect(batch_stocking.current_biomass_kg).to eq(4.0) # (1000 * 4g) / 1000
    end

    it "creates an initial biometry stocking event matching the stocked amounts" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0, stocked_on: Date.current)

      initial_event = batch_stocking.stocking_events.find_by(event_type: "biometrics")

      expect(initial_event).to be_present
      expect(initial_event.quantity).to eq(1000)
      expect(initial_event.avg_weight_g.to_f).to eq(4.0)
      expect(initial_event.occurred_on).to eq(Date.current)
    end
  end

  describe "#recalculate_current_balance!" do
    it "deducts mortality quantity and biomass from the current balance" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0, stocked_on: 2.days.ago.to_date)

      create(:stocking_event, :mortality,
        batch_stocking: batch_stocking,
        quantity: 100,
        occurred_on: Date.current)

      batch_stocking.reload

      expect(batch_stocking.current_quantity).to eq(900)
      expect(batch_stocking.current_biomass_kg.to_f).to eq(3.6) # (900 * 4g) / 1000
    end

    it "never lets the current balance go negative" do
      batch_stocking = create(:batch_stocking, quantity: 100, avg_weight_g: 4.0, stocked_on: 2.days.ago.to_date)

      create(:stocking_event, :mortality,
        batch_stocking: batch_stocking,
        quantity: 500,
        occurred_on: Date.current)

      batch_stocking.reload

      expect(batch_stocking.current_quantity).to eq(0)
      expect(batch_stocking.current_biomass_kg.to_f).to eq(0.0)
    end

    it "applies a later biometry to update the avg weight used for subsequent balance calculations" do
      batch_stocking = create(:batch_stocking, quantity: 1000, avg_weight_g: 4.0, stocked_on: 3.days.ago.to_date)

      create(:stocking_event, :biometrics,
        batch_stocking: batch_stocking,
        volume: 1000,
        quantity: 1000,
        total_weight_kg: 6.0, # avg_weight_g becomes 6.0g
        occurred_on: 1.day.ago.to_date)

      batch_stocking.reload

      expect(batch_stocking.current_biomass_kg.to_f).to eq(6.0) # (1000 * 6g) / 1000
    end
  end
end
