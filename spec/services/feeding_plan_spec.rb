require "rails_helper"

RSpec.describe FeedingPlan do
  # Faixas de temperatura como no CSV do cliente.
  let!(:temp_ranges) do
    [[15, 16], [17, 18], [19, 20], [21, 23], [24, 26], [27, 29], [30, 31]].map do |from, to|
      create(:feeding_temperature_range, temperature_from: from, temperature_to: to)
    end
  end

  let!(:weight_3_to_9) { create(:feeding_weight_range, weight_from: 3, weight_to: 9.9) }
  let!(:weight_10_to_13) { create(:feeding_weight_range, weight_from: 10, weight_to: 13.9) }

  let(:feeding_table) { create(:feeding_table) }

  # Linha "3 - 9,9 g" do CSV: 0,50% / 1,60% / 3,20% / 4,80% / 6,00% / 7,00% / 5,80%
  before do
    percentages = [0.5, 1.6, 3.2, 4.8, 6.0, 7.0, 5.8]
    temp_ranges.each_with_index do |temp_range, i|
      create(:feeding_strategy_item,
        feeding_table: feeding_table,
        feeding_weight_range: weight_3_to_9,
        feeding_temperature_range: temp_range,
        feeding_percentage: percentages[i])
    end
  end

  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }

  def stock_pond(biomass_kg:, quantity:)
    batch = create(:batch, pond: pond, stocking_quantity: quantity, stocking_avg_weight_g: 7.0)
    batch.batch_stockings.first.update_columns(current_biomass_kg: biomass_kg, current_quantity: quantity)
  end

  describe "#rows" do
    it "computes the feed (kg) per temperature as biomass * feeding_percentage" do
      stock_pond(biomass_kg: 6_900, quantity: 900_000) # avg 7,67 g -> faixa 3-9,9

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.pond).to eq(pond)
      expect(row.biomass_kg).to eq(6_900)
      expect(row.avg_weight_g).to be_within(0.01).of(7.67)
      expect(row.weight_range).to eq(weight_3_to_9)

      feed = temp_ranges.map { |tr| row.feed_kg_by_temp[tr.id].to_f }
      expect(feed).to eq([34.5, 110.4, 220.8, 331.2, 414.0, 483.0, 400.2])
    end

    it "estimates the time (min) from the feed and the pond's calibration sample" do
      stock_pond(biomass_kg: 6_900, quantity: 900_000)
      pond.update!(feed_sample_kg: 650, feed_sample_seconds: 964) # 1,4831 s/kg

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      # 34,5 kg * (964/650) / 60 ≈ 0,85 min ; 483 kg ≈ 11,94 min
      expect(row.time_min_by_temp[temp_ranges.first.id]).to be_within(0.05).of(0.85)
      expect(row.time_min_by_temp[temp_ranges.last.id]).to be_within(0.05).of(9.89)
    end

    it "leaves the time blank when the pond has no calibration" do
      stock_pond(biomass_kg: 6_900, quantity: 900_000)

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.feed_kg_by_temp.values).to all(be_present)
      expect(row.time_min_by_temp.values).to all(be_nil)
    end

    it "leaves everything blank for a pond whose average weight is outside every range" do
      stock_pond(biomass_kg: 100, quantity: 100) # avg 1000 g -> nenhuma faixa cadastrada

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.weight_range).to be_nil
      expect(row.feed_kg_by_temp.values).to all(be_nil)
    end

    it "leaves everything blank for a pond with no active batch" do
      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.biomass_kg).to eq(0)
      expect(row.feed_kg_by_temp.values).to all(be_nil)
    end

    it "sums the biomass of every active stocking in the pond" do
      create(:batch, pond: pond, stocking_quantity: 500_000, stocking_avg_weight_g: 7.0)
        .batch_stockings.first.update_columns(current_biomass_kg: 3_000, current_quantity: 400_000)
      create(:batch, pond: pond, stocking_quantity: 500_000, stocking_avg_weight_g: 7.0)
        .batch_stockings.first.update_columns(current_biomass_kg: 900, current_quantity: 100_000)

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.biomass_kg).to eq(3_900)
      expect(row.avg_weight_g).to be_within(0.01).of(7.8) # 3900 * 1000 / 500000
    end

    it "ignores stockings of closed batches" do
      create(:batch, pond: pond, status: "closed", stocking_quantity: 900_000)
        .batch_stockings.first.update_columns(current_biomass_kg: 5_000, current_quantity: 900_000)

      row = described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first

      expect(row.biomass_kg).to eq(0)
    end
  end
end
