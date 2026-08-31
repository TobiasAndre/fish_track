class AddDueOnToSiloStockEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :silo_stock_entries, :due_on, :date
  end
end
