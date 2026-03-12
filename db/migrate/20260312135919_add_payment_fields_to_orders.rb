class AddPaymentFieldsToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :payment_method, null: false, foreign_key: true
    add_reference :orders, :payment_term, null: false, foreign_key: true
  end
end
