# Consulta de entradas de estoque de ração com os filtros da tela (silo, lote,
# marca, tipo e período). Serve a listagem da tela e o relatório em PDF, para os
# dois mostrarem exatamente os mesmos dados.
class SiloStockReport
  FILTER_KEYS = %i[unit_id silo_id batch_id feeding_brand_id feeding_type_id from to].freeze

  attr_reader :unit_id, :silo_id, :batch_id, :feeding_brand_id, :from, :to

  def initialize(filters = {})
    filters = filters.to_h.with_indifferent_access
    @unit_id = filters[:unit_id].presence
    @silo_id = filters[:silo_id].presence
    @batch_id = filters[:batch_id].presence
    @feeding_brand_id = filters[:feeding_brand_id].presence
    @requested_feeding_type_id = filters[:feeding_type_id].presence
    @from = filters[:from].presence
    @to = filters[:to].presence
  end

  # Com uma marca filtrada, um tipo de outra marca que tenha sobrado no
  # parâmetro é ignorado.
  def feeding_type_id
    return @requested_feeding_type_id if @requested_feeding_type_id.blank?

    filter_feeding_types.any? { |type| type.id.to_s == @requested_feeding_type_id.to_s } ? @requested_feeding_type_id : nil
  end

  # Tipos que o filtro oferece: só os da marca, quando há marca filtrada.
  def filter_feeding_types
    @filter_feeding_types ||= begin
      types = FeedingType.includes(:feeding_brand).order(:name)
      feeding_brand_id.present? ? types.where(feeding_brand_id: feeding_brand_id).to_a : types.to_a
    end
  end

  # Filtros efetivamente aplicados (sem os vazios), para repassar a links e ao compartilhamento.
  def filters
    { unit_id: unit_id, silo_id: silo_id, batch_id: batch_id, feeding_brand_id: feeding_brand_id,
      feeding_type_id: feeding_type_id, from: from, to: to }.compact
  end

  def filtered?
    filters.except(:unit_id).any?
  end

  # Da entrada mais recente para a mais antiga.
  def scope
    @scope ||= begin
      relation = SiloStockEntry
        .includes(:batch, :payment_method, :payment_term, :financial_entries, silo: :unit, feeding_type: :feeding_brand)
        .left_joins(:silo)
        .recent_first

      relation = relation.where(silos: { unit_id: unit_id }) if unit_id.present?
      relation = relation.where(silo_id: silo_id) if silo_id.present?
      relation = relation.where(batch_id: batch_id) if batch_id.present?
      relation = relation.where(feeding_brand_id: feeding_brand_id) if feeding_brand_id.present?
      relation = relation.where(feeding_type_id: feeding_type_id) if feeding_type_id.present?
      relation = relation.where("silo_stock_entries.occurred_on >= ?", from) if from.present?
      relation = relation.where("silo_stock_entries.occurred_on <= ?", to) if to.present?
      relation
    end
  end

  # Totais do recorte filtrado (não só da página exibida).
  def entries_count
    scope.count
  end

  def total_kg
    scope.sum(:quantity_kg)
  end

  def total_cents
    scope.sum(:total_cents)
  end

  # Soma das entradas por silo, lote e tipo de ração (sem filtros: é o estoque de fato).
  def current_stock
    SiloStockEntry.group(:silo_id, :batch_id, :feeding_type_id).sum(:quantity_kg)
  end

  # Linhas do estoque atual já resolvidas e ordenadas: entradas sem silo por último,
  # depois por unidade, silo, lote e tipo. Cada linha: { silo:, batch:, feeding_type:, kg: }.
  def stock_rows
    silos = Silo.includes(:unit).index_by(&:id)
    batches = Batch.all.index_by(&:id)
    types = FeedingType.includes(:feeding_brand).index_by(&:id)

    rows = current_stock.select { |_key, kg| kg.to_d.positive? }.map do |(silo_id, batch_id, type_id), kg|
      { silo: silos[silo_id], batch: batches[batch_id], feeding_type: types[type_id], kg: kg }
    end

    rows.sort_by do |row|
      [row[:silo].nil? ? 1 : 0, row[:silo]&.unit&.name.to_s, row[:silo]&.name.to_s, row[:batch]&.name.to_s, row[:feeding_type]&.name.to_s]
    end
  end

  def stock_total_kg
    stock_rows.sum { |row| row[:kg].to_d }
  end
end
