class AddPaymentMethodToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :stocking_events, :payment_method, foreign_key: true
  end
end
