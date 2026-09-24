# Até aqui a baixa era só uma data (settled_on) e total. Converte cada
# lançamento já liquidado em um pagamento integral nessa data, para o histórico
# de pagamentos e o saldo (paid_cents) ficarem coerentes. Idempotente.
class BackfillPaymentsForSettledFinancialEntries < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO financial_payments (financial_entry_id, paid_on, amount_cents, created_at, updated_at)
      SELECT fe.id, fe.settled_on, fe.amount_cents, NOW(), NOW()
      FROM financial_entries fe
      WHERE fe.settled_on IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM financial_payments fp WHERE fp.financial_entry_id = fe.id)
    SQL

    execute "UPDATE financial_entries SET paid_cents = amount_cents WHERE settled_on IS NOT NULL"
  end

  def down
    execute "UPDATE financial_entries SET paid_cents = 0"
    execute "DELETE FROM financial_payments"
  end
end
