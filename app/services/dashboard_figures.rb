# Números do dashboard para os lotes ativos: peixes alojados e entregues
# (carregados) e o que já foi gasto/faturado no Financeiro em cada lote.
# Tudo em consultas agrupadas (sem N+1 por lote).
class DashboardFigures
  Figures = Struct.new(:loaded_quantity, :expense_cents, :revenue_cents, keyword_init: true)

  def initialize(batches)
    @batch_ids = batches.map(&:id)
  end

  # Peixes alojados: quantidade inicial de todas as lotações dos lotes ativos.
  def stocked_quantity
    @stocked_quantity ||= BatchStocking.where(batch_id: @batch_ids).sum(:quantity).to_i
  end

  # Peixes entregues: soma dos carregamentos dos lotes ativos.
  def delivered_quantity
    loaded_by_batch_id.values.sum
  end

  # Peixes a entregar: alojados menos entregues.
  def to_deliver_quantity
    stocked_quantity - delivered_quantity
  end

  def expense_cents
    money_by_batch_id.values.sum { |amounts| amounts["expense"].to_i }
  end

  def revenue_cents
    money_by_batch_id.values.sum { |amounts| amounts["income"].to_i }
  end

  # Saldo financeiro: faturamento menos despesa.
  def balance_cents
    revenue_cents - expense_cents
  end

  def for(batch)
    amounts = money_by_batch_id[batch.id] || {}

    Figures.new(
      loaded_quantity: loaded_by_batch_id[batch.id].to_i,
      expense_cents: amounts["expense"].to_i,
      revenue_cents: amounts["income"].to_i
    )
  end

  private

  def loaded_by_batch_id
    @loaded_by_batch_id ||=
      StockingEvent
        .where(event_type: "loading")
        .joins(:batch_stocking)
        .where(batch_stockings: { batch_id: @batch_ids })
        .group("batch_stockings.batch_id")
        .sum(:quantity)
  end

  # { batch_id => { "expense" => cents, "income" => cents } }
  def money_by_batch_id
    @money_by_batch_id ||=
      FinancialEntry
        .where(batch_id: @batch_ids)
        .group(:batch_id, :entry_type)
        .sum(:amount_cents)
        .each_with_object({}) { |((batch_id, entry_type), cents), memo| (memo[batch_id] ||= {})[entry_type] = cents }
  end
end
