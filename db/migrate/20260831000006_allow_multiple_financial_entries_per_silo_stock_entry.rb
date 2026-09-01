class AllowMultipleFinancialEntriesPerSiloStockEntry < ActiveRecord::Migration[7.1]
  # A silo stock entry paid in installments generates one financial entry per
  # installment, so the silo_stock_entry_id can no longer be unique.
  def up
    remove_index :financial_entries, column: :silo_stock_entry_id
    add_index :financial_entries, :silo_stock_entry_id
  end

  def down
    remove_index :financial_entries, column: :silo_stock_entry_id
    add_index :financial_entries, :silo_stock_entry_id, unique: true
  end
end
