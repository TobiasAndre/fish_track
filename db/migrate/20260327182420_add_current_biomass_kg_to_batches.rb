class AddCurrentBiomassKgToBatches < ActiveRecord::Migration[7.1]
  def change
    add_column :batches, :current_biomass_kg, :decimal, precision: 14, scale: 3
  end
end
