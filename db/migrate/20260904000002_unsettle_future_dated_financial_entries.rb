class UnsettleFutureDatedFinancialEntries < ActiveRecord::Migration[7.1]
  # A migração de backfill marcou TODO lançamento existente como liquidado
  # (settled_on = occurred_on), para preservar o comportamento antigo em que
  # o financeiro tratava tudo como realizado. Isso produziu registros
  # contraditórios: parcelas com vencimento futuro (ex.: ração parcelada,
  # adiantamentos) aparecendo como "liquidadas" numa data que ainda não
  # chegou. Uma baixa nunca pode estar no futuro — esses casos são, na
  # verdade, contas em aberto.
  def up
    execute <<~SQL.squish
      UPDATE financial_entries
      SET settled_on = NULL
      WHERE settled_on > CURRENT_DATE
    SQL
  end

  def down
    # Sem volta: não há como saber quais eram os settled_on originais.
  end
end
