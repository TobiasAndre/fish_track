class AddStockingEventToFinancialEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :financial_entries, :stocking_event, foreign_key: true, null: true
  end
end
