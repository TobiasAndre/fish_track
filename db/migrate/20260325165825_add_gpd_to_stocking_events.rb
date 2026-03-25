class AddGpdToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :gpd, :decimal, precision: 10, scale: 3
  end
end
