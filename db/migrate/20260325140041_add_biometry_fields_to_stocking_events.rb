class AddBiometryFieldsToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :total_weight_kg, :decimal, precision: 10, scale: 3
    add_column :stocking_events, :volume, :decimal, precision: 10, scale: 2
    add_column :stocking_events, :biomass, :decimal, precision: 12, scale: 3
  end
end
