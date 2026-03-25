class AddCurrentFieldsToBatchStockings < ActiveRecord::Migration[7.1]
  def change
    add_column :batch_stockings, :current_quantity, :integer
    add_column :batch_stockings, :current_biomass_kg, :decimal, precision: 12, scale: 3
  end
end
