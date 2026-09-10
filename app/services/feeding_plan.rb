# Monta o plano de arraçoamento por tanque: quanto de ração (kg) e quanto tempo
# (min) dar em cada faixa de temperatura da água.
#
#   trato_kg  = biomassa_kg * %arraçoamento(faixa_de_peso, faixa_de_temp) / 100
#   tempo_min = trato_kg * (segundos_amostra / kg_amostra) / 60
#
# Biomassa e peso médio vêm dos lotes ativos de cada tanque; o percentual vem da
# tabela de arraçoamento (feeding_strategy_items); a calibração de tempo vem dos
# campos feed_sample_* do próprio tanque.
class FeedingPlan
  Row = Struct.new(
    :pond, :biomass_kg, :avg_weight_g, :weight_range,
    :feed_kg_by_temp, :time_min_by_temp,
    keyword_init: true
  )

  def initialize(feeding_table:, ponds:)
    @feeding_table = feeding_table
    @ponds = ponds.to_a
  end

  def temperature_ranges
    @temperature_ranges ||= FeedingTemperatureRange.order(:temperature_from).to_a
  end

  def rows
    @rows ||= @ponds.map { |pond| build_row(pond) }
  end

  private

  def weight_ranges
    @weight_ranges ||= FeedingWeightRange.order(:weight_from).to_a
  end

  def strategy_matrix
    @strategy_matrix ||=
      (@feeding_table&.feeding_strategy_items.to_a).index_by do |item|
        [item.feeding_weight_range_id, item.feeding_temperature_range_id]
      end
  end

  # { pond_id => { biomass_kg: BigDecimal, quantity: Integer } } dos lotes ativos.
  def active_totals_by_pond_id
    @active_totals_by_pond_id ||=
      BatchStocking
        .joins(:batch)
        .where(batches: { status: "active" }, pond_id: @ponds.map(&:id))
        .group(:pond_id)
        .pluck(
          :pond_id,
          Arel.sql("COALESCE(SUM(batch_stockings.current_biomass_kg), 0)"),
          Arel.sql("COALESCE(SUM(batch_stockings.current_quantity), 0)")
        )
        .to_h { |pond_id, biomass, quantity| [pond_id, { biomass_kg: biomass.to_d, quantity: quantity.to_i }] }
  end

  def build_row(pond)
    totals = active_totals_by_pond_id[pond.id] || { biomass_kg: 0.to_d, quantity: 0 }
    biomass_kg = totals[:biomass_kg]
    avg_weight_g = totals[:quantity].positive? ? (biomass_kg * 1000 / totals[:quantity]) : 0.to_d
    weight_range = weight_range_for(avg_weight_g)
    seconds_per_kg = pond.feed_seconds_per_kg

    feed_kg_by_temp = {}
    time_min_by_temp = {}

    temperature_ranges.each do |temp_range|
      percentage = weight_range && strategy_matrix[[weight_range.id, temp_range.id]]&.feeding_percentage
      feed_kg = percentage && biomass_kg.positive? ? (biomass_kg * percentage / 100) : nil

      feed_kg_by_temp[temp_range.id] = feed_kg
      time_min_by_temp[temp_range.id] = feed_kg && seconds_per_kg ? (feed_kg * seconds_per_kg / 60) : nil
    end

    Row.new(
      pond: pond,
      biomass_kg: biomass_kg,
      avg_weight_g: avg_weight_g,
      weight_range: weight_range,
      feed_kg_by_temp: feed_kg_by_temp,
      time_min_by_temp: time_min_by_temp
    )
  end

  def weight_range_for(avg_weight_g)
    return if avg_weight_g <= 0

    weight_ranges.find { |range| range.weight_from <= avg_weight_g && avg_weight_g <= range.weight_to }
  end
end
