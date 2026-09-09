class AddOrderNumberToPonds < ActiveRecord::Migration[7.1]
  def change
    add_column :ponds, :order_number, :integer, null: false, default: 0
  end
end
