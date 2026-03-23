class CreateSimulationProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :simulation_products do |t|
      t.references :simulation, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end

    add_index :simulation_products, [:simulation_id, :product_id], unique: true
  end
end
