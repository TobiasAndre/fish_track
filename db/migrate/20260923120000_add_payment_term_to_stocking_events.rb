class AddPaymentTermToStockingEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :stocking_events, :payment_term, foreign_key: true, null: true
  end
end
