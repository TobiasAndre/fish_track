# Gera as contas a receber dos carregamentos já lançados antes de o
# lançamento de carregamento passar a alimentar o Financeiro. Carregamentos
# antigos não têm condição de pagamento, então geram uma única parcela na data
# de vencimento (payment_date) ou, na falta dela, na data do carregamento.
# Idempotente: pula carregamentos que já possuem lançamento financeiro.
class BackfillFinancialEntriesForLoadingEvents < ActiveRecord::Migration[8.1]
  class MigrationFinancialEntry < ActiveRecord::Base
    self.table_name = "financial_entries"
  end

  def up
    rows = select_all(<<~SQL.squish)
      SELECT se.id, se.occurred_on, se.payment_date, se.total_cents,
             b.id AS batch_id, b.name AS batch_name, b.stage AS batch_stage,
             p.unit_id AS unit_id, c.name AS customer_name
      FROM stocking_events se
      INNER JOIN batch_stockings bs ON bs.id = se.batch_stocking_id
      INNER JOIN batches b ON b.id = bs.batch_id
      INNER JOIN ponds p ON p.id = bs.pond_id
      LEFT JOIN customers c ON c.id = se.customer_id
      WHERE se.event_type = 'loading'
        AND se.total_cents > 0
        AND NOT EXISTS (SELECT 1 FROM financial_entries fe WHERE fe.stocking_event_id = se.id)
      ORDER BY se.id
    SQL

    rows.each do |row|
      MigrationFinancialEntry.create!(
        entry_type: "income",
        stage: %w[nursery juvenile growout general].include?(row["batch_stage"]) ? row["batch_stage"] : "general",
        occurred_on: row["occurred_on"],
        due_on: row["payment_date"].presence || row["occurred_on"],
        amount_cents: row["total_cents"],
        description: ["Carregamento", row["customer_name"], row["batch_name"]].compact.join(" - "),
        unit_id: row["unit_id"],
        batch_id: row["batch_id"],
        stocking_event_id: row["id"]
      )
    end
  end

  def down
    execute "DELETE FROM financial_entries WHERE stocking_event_id IS NOT NULL"
  end
end
