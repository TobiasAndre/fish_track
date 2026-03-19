class CreateSimulations < ActiveRecord::Migration[7.1]
  def change
    create_table :simulations do |t|
      t.references :customer, null: false, foreign_key: true
      t.date :simulated_on, null: false
      t.integer :quantity, null: false, default: 0
      t.decimal :avg_weight_kg, precision: 10, scale: 3, null: false, default: 0
      t.decimal :total_weight_kg, precision: 12, scale: 3, null: false, default: 0
      t.bigint :price_per_kg_cents, null: false, default: 0
      t.bigint :loading_cost_cents, null: false, default: 0
      t.bigint :freight_cost_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :simulations, :simulated_on
  end
end
