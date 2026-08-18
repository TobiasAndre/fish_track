class AddSupplierToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :stocking_events, :supplier, null: true, foreign_key: true
  end
end
