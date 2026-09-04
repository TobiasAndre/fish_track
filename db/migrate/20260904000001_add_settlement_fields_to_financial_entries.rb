class AddSettlementFieldsToFinancialEntries < ActiveRecord::Migration[7.1]
  # Contas a pagar/receber: `due_on` é o vencimento e `settled_on` a data da
  # baixa (nil = em aberto). `occurred_on` continua sendo a competência.
  def up
    add_column :financial_entries, :due_on, :date
    add_column :financial_entries, :settled_on, :date

    # Lançamentos já existentes mantêm o comportamento atual: o financeiro
    # tratava tudo como realizado, então vencimento = competência e todos
    # entram como já liquidados.
    execute <<~SQL.squish
      UPDATE financial_entries
      SET due_on = occurred_on,
          settled_on = occurred_on
    SQL

    change_column_null :financial_entries, :due_on, false

    add_index :financial_entries, :due_on
    add_index :financial_entries, :settled_on
  end

  def down
    remove_column :financial_entries, :settled_on
    remove_column :financial_entries, :due_on
  end
end
