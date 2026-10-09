class RecalculateBatchStockingBalances < ActiveRecord::Migration[8.1]
  # Refaz saldo e biomassa de todos os alojamentos com a regra nova (o peso médio
  # do carregamento passa a ser o peso médio do tanque) e corrige os que ficaram
  # desatualizados ao editar o alojamento no lote. Roda em cada schema de empresa.
  def up
    BatchStocking.reset_column_information
    BatchStocking.includes(:batch).find_each(&:recalculate_current_balance!)
  end

  def down
    # Nada a desfazer: os saldos são recalculados a partir dos eventos.
  end
end
