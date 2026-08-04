require "rails_helper"

RSpec.describe Batch, type: :model do
  it "is valid with a name, started_on, status, stage and a batch stocking" do
    expect(build(:batch)).to be_valid
  end

  it "is invalid without a name" do
    batch = build(:batch, name: nil)

    expect(batch).not_to be_valid
    expect(batch.errors[:name]).to be_present
  end

  it "is invalid without at least one batch stocking" do
    batch = build(:batch)
    batch.batch_stockings.clear

    expect(batch).not_to be_valid
    expect(batch.errors[:batch_stockings]).to be_present
  end

  it "is invalid when its stockings span more than one unit" do
    unit_a = create(:unit)
    unit_b = create(:unit)
    pond_a = create(:pond, unit: unit_a)
    pond_b = create(:pond, unit: unit_b)

    batch = build(:batch, pond: pond_a)
    batch.batch_stockings.build(pond: pond_b, quantity: 500, avg_weight_g: 5.0, stocked_on: Date.current)

    expect(batch).not_to be_valid
    expect(batch.errors[:base]).to include("Os tanques selecionados devem pertencer à mesma unidade")
  end

  describe "#unit" do
    it "returns the unit of its first pond" do
      unit = create(:unit)
      pond = create(:pond, unit: unit)
      batch = create(:batch, pond: pond)

      expect(batch.unit).to eq(unit)
    end
  end

  describe "#sync_batch_totals_from_stockings" do
    it "sums the current_quantity and avg-weight-derived biomass from its stockings on create" do
      batch = build(:batch, stocking_quantity: 1000, stocking_avg_weight_g: 10)

      batch.save!

      expect(batch.current_quantity).to eq(1000)
      expect(batch.current_biomass_kg).to eq(10) # (1000 * 10g) / 1000
    end
  end

  describe "#recalculate_current_quantity!" do
    it "sums current_quantity across all of its batch stockings" do
      batch = create(:batch)
      batch.batch_stockings.first.update_columns(current_quantity: 300)
      create(:batch_stocking, batch: batch, quantity: 200, avg_weight_g: 5.0).update_columns(current_quantity: 200)

      batch.recalculate_current_quantity!

      expect(batch.reload.current_quantity).to eq(500)
    end
  end

  describe "#recalculate_current_biomass!" do
    it "sums current_biomass_kg across all of its batch stockings" do
      batch = create(:batch)
      batch.batch_stockings.first.update_columns(current_biomass_kg: 3.5)
      create(:batch_stocking, batch: batch, quantity: 200, avg_weight_g: 5.0).update_columns(current_biomass_kg: 1.5)

      batch.recalculate_current_biomass!

      expect(batch.reload.current_biomass_kg).to eq(5.0)
    end
  end

  describe "#current_pond" do
    it "returns the pond of the most recently stocked batch stocking" do
      batch = create(:batch, stocked_on: 10.days.ago.to_date)
      newest_stocking = create(:batch_stocking, batch: batch, quantity: 200, avg_weight_g: 5.0, stocked_on: Date.current)

      expect(batch.current_pond).to eq(newest_stocking.pond)
    end
  end
end
