class AddShareTokenToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :share_token, :string
    add_index :stocking_events, :share_token, unique: true
  end
end
