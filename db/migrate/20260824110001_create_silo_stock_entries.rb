class CreateSiloStockEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :silo_stock_entries do |t|
      t.references :silo, null: false, foreign_key: true
      t.references :feeding_type, null: false, foreign_key: true
      t.references :feeding_brand, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.decimal :quantity_kg, precision: 10, scale: 3, null: false
      t.bigint :total_cents, null: false, default: 0
      t.integer :price_per_kg_cents, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :silo_stock_entries, :occurred_on

    add_reference :financial_entries, :silo_stock_entry, null: true, foreign_key: true, index: { unique: true }
  end
end
