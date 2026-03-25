class AddWeightGainKgToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :weight_gain_kg, :decimal, precision: 12, scale: 3
  end
end
