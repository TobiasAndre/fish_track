class CreateFeedingStrategyItems < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_strategy_items do |t|
      t.references :feeding_table, null: false, foreign_key: true
      t.references :feeding_weight_range, null: false, foreign_key: true
      t.references :feeding_temperature_range, null: false, foreign_key: true

      t.decimal :feeding_percentage, precision: 5, scale: 2, null: false

      t.timestamps
    end

    add_index :feeding_strategy_items,
              [:feeding_table_id, :feeding_weight_range_id, :feeding_temperature_range_id],
              unique: true,
              name: "idx_feeding_strategy_items_unique_cell"
  end
end