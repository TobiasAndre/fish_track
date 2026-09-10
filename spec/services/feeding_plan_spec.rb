require "rails_helper"

RSpec.describe FeedingPlan do
  # Faixas de temperatura como no CSV do cliente (7 faixas).
  let!(:temp_ranges) do
    [[15, 16], [17, 18], [19, 20], [21, 23], [24, 26], [27, 29], [30, 31]].map do |from, to|
      create(:feeding_temperature_range, temperature_from: from, temperature_to: to)
    end
  end

  # Faixas de peso contíguas com "folga" de 0,1 g entre elas (como no Excel).
  let!(:weight_0_to_2) { create(:feeding_weight_range, weight_from: 0.3, weight_to: 2.9) }
  let!(:weight_3_to_9) { create(:feeding_weight_range, weight_from: 3, weight_to: 9.9) }
  let!(:weight_10_to_13) { create(:feeding_weight_range, weight_from: 10, weight_to: 13.9) }

  let(:feeding_table) { create(:feeding_table) }

  # Linha "3 - 9,9 g" do CSV: 0,50% / 1,60% / 3,20% / 4,80% / 6,00% / 7,00% / 5,80%
  let(:rates_3_to_9) { [0.5, 1.6, 3.2, 4.8, 6.0, 7.0, 5.8] }

  before do
    temp_ranges.each_with_index do |temp_range, i|
      create(:feeding_strategy_item,
        feeding_table: feeding_table, feeding_weight_range: weight_3_to_9,
        feeding_temperature_range: temp_range, feeding_percentage: rates_3_to_9[i])
      create(:feeding_strategy_item,
        feeding_table: feeding_table, feeding_weight_range: weight_10_to_13,
        feeding_temperature_range: temp_range, feeding_percentage: 2.0)
    end
  end

  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }

  # Força a biomassa e a quantidade correntes (fonte canônica) de forma que
  # avg = biomassa * 1000 / quantidade caia num peso conhecido.
  def stock(target_pond, biomass_kg:, quantity:)
    create(:batch, pond: target_pond, stocking_quantity: quantity, stocking_avg_weight_g: 7.0)
      .batch_stockings.first
      .update_columns(current_biomass_kg: biomass_kg, current_quantity: quantity)
  end

  def row_for(target_pond)
    described_class.new(feeding_table: feeding_table, ponds: [target_pond]).rows.first
  end

  describe "#rows — trato por tanque" do
    it "computa o trato como biomassa * taxa (6900 kg x 6% = 414 kg)" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000) # avg 7,67 g -> faixa 3-9,9

      row = row_for(pond)

      expect(row.quantity).to eq(900_000)
      expect(row.biomass_kg).to eq(6_900)
      expect(row.avg_weight_g).to be_within(0.01).of(7.67)
      expect(row.weight_range).to eq(weight_3_to_9)

      feed = temp_ranges.map { |tr| row.feed_kg_by_temp[tr.id].to_f }
      expect(feed).to eq([34.5, 110.4, 220.8, 331.2, 414.0, 483.0, 400.2])
      expect(row.feed_kg_by_temp[temp_ranges[4].id]).to eq(BigDecimal("414")) # 24-26°C
    end

    it "usa a faixa quando o peso está exatamente no início dela" do
      stock(pond, biomass_kg: 1_000, quantity: 100_000) # avg exatamente 10,0 g

      row = row_for(pond)

      expect(row.avg_weight_g).to eq(10)
      expect(row.weight_range).to eq(weight_10_to_13) # e não a faixa 3-9,9
      expect(row.feed_kg_by_temp[temp_ranges.first.id]).to eq(20) # 1000 * 2%
    end

    it "usa a faixa anterior para um peso na folga entre duas faixas (VLOOKUP TRUE)" do
      stock(pond, biomass_kg: 995, quantity: 100_000) # avg 9,95 g -> entre 3-9,9 e 10-13,9

      row = row_for(pond)

      expect(row.weight_range).to eq(weight_3_to_9)
    end

    it "muda de faixa na transição entre duas faixas" do
      stock(pond, biomass_kg: 999, quantity: 100_000)  # avg 9,99 -> faixa 3-9,9
      expect(row_for(pond).weight_range).to eq(weight_3_to_9)

      pond.batch_stockings.first.update_columns(current_biomass_kg: 1_001) # avg 10,01 -> faixa 10-13,9
      expect(described_class.new(feeding_table: feeding_table, ponds: [pond]).rows.first.weight_range)
        .to eq(weight_10_to_13)
    end

    it "não escolhe faixa quando o peso está abaixo da menor faixa" do
      stock(pond, biomass_kg: 1, quantity: 100_000) # avg 0,01 g

      row = row_for(pond)

      expect(row.weight_range).to be_nil
      expect(row.feed_kg_by_temp.values).to all(be_nil) # nunca zero
    end

    it "deixa o trato indisponível para tanque sem quantidade / biomassa (sem lote ativo)" do
      row = row_for(pond)

      expect(row.quantity).to eq(0)
      expect(row.biomass_kg).to eq(0)
      expect(row.avg_weight_g).to eq(0)
      expect(row.feed_kg_by_temp.values).to all(be_nil)
    end

    it "deixa o trato indisponível quando não há peso médio (quantidade sem biomassa)" do
      stock(pond, biomass_kg: 0, quantity: 100_000)

      row = row_for(pond)

      expect(row.avg_weight_g).to eq(0)
      expect(row.weight_range).to be_nil
      expect(row.feed_kg_by_temp.values).to all(be_nil)
    end

    it "deixa a célula indisponível quando falta a taxa para uma combinação peso x temperatura" do
      FeedingStrategyItem
        .where(feeding_table: feeding_table, feeding_weight_range: weight_3_to_9, feeding_temperature_range: temp_ranges[2])
        .delete_all
      stock(pond, biomass_kg: 6_900, quantity: 900_000)

      row = row_for(pond)

      expect(row.feed_kg_by_temp[temp_ranges[2].id]).to be_nil       # sem taxa cadastrada -> "—"
      expect(row.feed_kg_by_temp[temp_ranges[4].id]).to eq(BigDecimal("414")) # demais seguem calculando
    end

    it "soma a biomassa e a quantidade de todos os lotes ativos do tanque" do
      stock(pond, biomass_kg: 3_000, quantity: 400_000)
      create(:batch, pond: pond, stocking_quantity: 100_000, stocking_avg_weight_g: 7.0)
        .batch_stockings.first.update_columns(current_biomass_kg: 900, current_quantity: 100_000)

      row = row_for(pond)

      expect(row.quantity).to eq(500_000)
      expect(row.biomass_kg).to eq(3_900)
      expect(row.avg_weight_g).to be_within(0.01).of(7.8)
    end

    it "ignora lotes fechados" do
      create(:batch, pond: pond, status: "closed", stocking_quantity: 900_000)
        .batch_stockings.first.update_columns(current_biomass_kg: 5_000, current_quantity: 900_000)

      expect(row_for(pond).biomass_kg).to eq(0)
    end

    it "usa cálculo decimal (sem float impreciso)" do
      stock(pond, biomass_kg: 6_900, quantity: 900_000)

      value = row_for(pond).feed_kg_by_temp[temp_ranges[4].id]

      expect(value).to be_a(BigDecimal)
      expect(value).to eq(BigDecimal("414"))
    end
  end

  describe "#temperature_ranges — colunas dinâmicas" do
    it "reflete as faixas de temperatura cadastradas, em ordem" do
      plan = described_class.new(feeding_table: feeding_table, ponds: [])
      expect(plan.temperature_ranges).to eq(temp_ranges) # ordenadas por temperature_from

      nova = create(:feeding_temperature_range, temperature_from: 32, temperature_to: 34)
      expect(described_class.new(feeding_table: feeding_table, ponds: []).temperature_ranges.last).to eq(nova)
    end
  end
end
