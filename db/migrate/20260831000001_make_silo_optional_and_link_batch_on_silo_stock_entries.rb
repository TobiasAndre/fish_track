class MakeSiloOptionalAndLinkBatchOnSiloStockEntries < ActiveRecord::Migration[7.1]
  def change
    change_column_null :silo_stock_entries, :silo_id, true
    add_reference :silo_stock_entries, :batch, null: true, foreign_key: true
  end
end
