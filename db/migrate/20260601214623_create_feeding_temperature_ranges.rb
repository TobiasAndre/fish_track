class CreateFeedingTemperatureRanges < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_temperature_ranges do |t|
      t.decimal :temperature_from, precision: 5, scale: 2, null: false
      t.decimal :temperature_to, precision: 5, scale: 2, null: false

      t.timestamps
    end

    add_index :feeding_temperature_ranges,
              [:temperature_from, :temperature_to],
              unique: true,
              name: "idx_feeding_temperature_ranges"
  end
end