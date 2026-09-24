# Resultado financeiro por lote, a partir dos lançamentos do Financeiro que
# têm lote: receita (entradas) x custo (saídas), resultado e margem, mais o
# lado de caixa (já recebido / já pago). O período filtra pela data de
# competência (occurred_on), como a tela do Financeiro.
class BatchResult
  Row = Struct.new(:batch, :revenue_cents, :cost_cents, :received_cents, :paid_cents, keyword_init: true) do
    def result_cents
      revenue_cents - cost_cents
    end

    # Resultado / receita. Sem receita não há margem a calcular.
    def margin_percent
      return nil unless revenue_cents.positive?

      (result_cents.to_d / revenue_cents * 100).round(1)
    end

    def cash_result_cents
      received_cents - paid_cents
    end

    def receivable_cents
      revenue_cents - received_cents
    end

    def payable_cents
      cost_cents - paid_cents
    end
  end

  STATUSES = %w[active closed].freeze

  attr_reader :status, :from, :to

  def initialize(status: nil, from: nil, to: nil)
    @status = status.presence_in(STATUSES)
    @from = parse_date(from)
    @to = parse_date(to)
  end

  # Lotes que têm lançamentos no período, do mais recente para o mais antigo.
  def rows
    @rows ||= batches.filter_map do |batch|
      totals = sums_by_batch_id[batch.id]
      next if totals.nil?

      build_row(batch, totals)
    end
  end

  def total
    @total ||= Row.new(
      batch: nil,
      revenue_cents: rows.sum(&:revenue_cents),
      cost_cents: rows.sum(&:cost_cents),
      received_cents: rows.sum(&:received_cents),
      paid_cents: rows.sum(&:paid_cents)
    )
  end

  # Lançamentos sem lote (folha, despesas gerais...): ficam de fora do
  # resultado dos lotes, mas aparecem para não esconder custo nenhum.
  def unallocated
    @unallocated ||= build_row(nil, sums_by_batch_id[nil] || {})
  end

  def batches_without_entries_count
    batches.size - rows.size
  end

  private

  def batches
    @batches ||= begin
      scope = Batch.order(started_on: :desc, id: :desc)
      scope = scope.where(status: status) if status
      scope.to_a
    end
  end

  def sums_by_batch_id
    @sums_by_batch_id ||= begin
      scope = FinancialEntry.all
      scope = scope.where("financial_entries.occurred_on >= ?", from) if from
      scope = scope.where("financial_entries.occurred_on <= ?", to) if to

      scope
        .group(:batch_id, :entry_type)
        .pluck(:batch_id, :entry_type, Arel.sql("SUM(amount_cents)"), Arel.sql("SUM(LEAST(paid_cents, amount_cents))"))
        .each_with_object({}) do |(batch_id, entry_type, amount, paid), memo|
          (memo[batch_id] ||= {})[entry_type] = [amount.to_i, paid.to_i]
        end
    end
  end

  def build_row(batch, totals)
    income_amount, income_paid = totals["income"] || [0, 0]
    expense_amount, expense_paid = totals["expense"] || [0, 0]

    Row.new(
      batch: batch,
      revenue_cents: income_amount, cost_cents: expense_amount,
      received_cents: income_paid, paid_cents: expense_paid
    )
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end
end
