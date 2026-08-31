require "rails_helper"

RSpec.describe SiloStockEntry, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:silo_stock_entry) }
  end

  it "is valid with a silo, a feeding_type, a date and a positive quantity" do
    expect(build(:silo_stock_entry)).to be_valid
  end

  it "is valid without a silo (silo is optional)" do
    expect(build(:silo_stock_entry, silo: nil)).to be_valid
  end

  it "is invalid when the referenced silo does not exist" do
    entry = build(:silo_stock_entry)
    entry.silo_id = 999_999

    expect(entry).not_to be_valid
    expect(entry.errors[:silo]).to be_present
  end

  it "can be linked to an existing batch" do
    batch = create(:batch)
    entry = create(:silo_stock_entry, batch: batch)

    expect(entry.reload.batch).to eq(batch)
  end

  it "is invalid without a feeding_type" do
    entry = build(:silo_stock_entry, feeding_type: nil)

    expect(entry).not_to be_valid
    expect(entry.errors[:feeding_type]).to be_present
  end

  it "is invalid without a positive quantity_kg" do
    entry = build(:silo_stock_entry, quantity_kg: 0)

    expect(entry).not_to be_valid
    expect(entry.errors[:quantity_kg]).to be_present
  end

  it "is invalid with a negative total_cents" do
    entry = build(:silo_stock_entry, total_cents: -1)

    expect(entry).not_to be_valid
    expect(entry.errors[:total_cents]).to be_present
  end

  it "accepts a zero total_cents (e.g. donated ration)" do
    entry = build(:silo_stock_entry, total_cents: 0)

    expect(entry).to be_valid
  end

  describe "#sync_feeding_brand_from_type" do
    it "derives feeding_brand from the selected feeding_type's brand" do
      brand = create(:feeding_brand, name: "Guabi")
      type = create(:feeding_type, name: "Extrusada 32%", feeding_brand: brand)

      entry = create(:silo_stock_entry, feeding_type: type)

      expect(entry.feeding_brand).to eq(brand)
    end
  end

  describe "#calculate_price_per_kg_cents" do
    it "derives price_per_kg_cents from total_cents and quantity_kg" do
      entry = build(:silo_stock_entry, quantity_kg: 50, total_cents: 25_000)

      entry.valid?

      expect(entry.price_per_kg_cents).to eq(500) # R$ 250,00 / 50kg = R$ 5,00/kg
    end

    it "recalculates price_per_kg_cents whenever quantity_kg or total_cents change" do
      entry = create(:silo_stock_entry, quantity_kg: 50, total_cents: 25_000)
      expect(entry.price_per_kg_cents).to eq(500)

      entry.update!(quantity_kg: 100)
      expect(entry.price_per_kg_cents).to eq(250)

      entry.update!(total_cents: 40_000)
      expect(entry.price_per_kg_cents).to eq(400)
    end
  end

  describe "financial entry integration" do
    it "creates a matching expense financial entry on create" do
      silo = create(:silo)
      entry = create(:silo_stock_entry, silo: silo, quantity_kg: 50, total_cents: 25_000)

      financial_entry = entry.reload.financial_entry
      expect(financial_entry).to be_present
      expect(financial_entry.entry_type).to eq("expense")
      expect(financial_entry.amount_cents).to eq(25_000)
      expect(financial_entry.unit_id).to eq(silo.unit_id)
      expect(financial_entry.silo_stock_entry_id).to eq(entry.id)
    end

    it "updates the financial entry's amount without creating a second one when the entry is edited" do
      entry = create(:silo_stock_entry, quantity_kg: 50, total_cents: 25_000)

      expect do
        entry.update!(total_cents: 40_000)
      end.not_to change(FinancialEntry, :count)

      expect(entry.financial_entry.reload.amount_cents).to eq(40_000)
    end

    it "removes the financial entry when the amount is edited down to zero" do
      entry = create(:silo_stock_entry, quantity_kg: 50, total_cents: 25_000)
      financial_entry = entry.financial_entry

      entry.update!(total_cents: 0)

      expect(FinancialEntry.exists?(financial_entry.id)).to be false
      expect(entry.reload.financial_entry).to be_nil
    end

    it "removes the financial entry when the silo stock entry is destroyed" do
      entry = create(:silo_stock_entry, quantity_kg: 50, total_cents: 25_000)
      financial_entry = entry.financial_entry

      entry.destroy

      expect(FinancialEntry.exists?(financial_entry.id)).to be false
    end

    it "attributes the financial entry to the linked batch (and its stage/unit)" do
      unit = create(:unit)
      pond = create(:pond, unit: unit)
      batch = create(:batch, pond: pond, stage: "growout")
      entry = create(:silo_stock_entry, silo: nil, batch: batch, quantity_kg: 50, total_cents: 25_000)

      financial_entry = entry.reload.financial_entry
      expect(financial_entry).to be_present
      expect(financial_entry.batch_id).to eq(batch.id)
      expect(financial_entry.stage).to eq("growout")
      expect(financial_entry.unit_id).to eq(unit.id)
    end

    it "labels the financial entry with the feeding type, brand and silo" do
      feeding_brand = create(:feeding_brand, name: "Guabi")
      feeding_type = create(:feeding_type, name: "Extrusada 32%", feeding_brand: feeding_brand)
      silo = create(:silo, name: "Silo Norte")
      entry = create(:silo_stock_entry, silo: silo, feeding_type: feeding_type)

      expect(entry.financial_entry.description).to include("Ração")
      expect(entry.financial_entry.description).to include("Extrusada 32%")
      expect(entry.financial_entry.description).to include("Guabi")
      expect(entry.financial_entry.description).to include("Silo Norte")
    end

    it "supports multiple entries for the same silo, each with its own financial entry" do
      silo = create(:silo)

      first = create(:silo_stock_entry, silo: silo, quantity_kg: 200, total_cents: 100_000)
      second = create(:silo_stock_entry, silo: silo, quantity_kg: 300, total_cents: 150_000)

      expect(silo.stock_entries.count).to eq(2)
      expect(first.financial_entry.id).not_to eq(second.financial_entry.id)
      expect(FinancialEntry.where(silo_stock_entry_id: [first.id, second.id]).count).to eq(2)
    end
  end
end
