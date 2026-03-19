class CreateBatchStockings < ActiveRecord::Migration[7.1]
  def change
    create_table :batch_stockings do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :pond, null: false, foreign_key: true
      t.references :supplier, foreign_key: true

      t.integer :quantity, null: false
      t.date :stocked_on, null: false
      t.decimal :avg_weight_g, precision: 10, scale: 2

      t.timestamps
    end

    add_index :batch_stockings, [:batch_id, :pond_id, :stocked_on], name: "idx_batch_stockings_batch_pond_date"
  end
end
