class AddPaymentFieldsToSiloStockEntries < ActiveRecord::Migration[7.1]
  def change
    add_reference :silo_stock_entries, :payment_method, null: true, foreign_key: true
    add_reference :silo_stock_entries, :payment_term, null: true, foreign_key: true
  end
end
