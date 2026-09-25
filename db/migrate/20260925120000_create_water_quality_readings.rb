class CreateWaterQualityReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :water_quality_readings do |t|
      t.references :pond, null: false, foreign_key: true
      t.datetime :measured_at, null: false

      # Parâmetros (todos opcionais; pelo menos um é exigido no model).
      t.decimal :ph, precision: 4, scale: 2                 # adimensional
      t.decimal :nitrite, precision: 7, scale: 3            # mg/L
      t.decimal :ammonia, precision: 7, scale: 3            # mg/L
      t.decimal :alkalinity, precision: 8, scale: 2         # mg/L CaCO3
      t.decimal :salinity, precision: 6, scale: 2           # ppt (g/L)

      t.text :notes

      t.timestamps
    end

    add_index :water_quality_readings, %i[pond_id measured_at]
  end
end
