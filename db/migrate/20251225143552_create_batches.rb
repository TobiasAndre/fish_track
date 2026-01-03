class CreateBatches < ActiveRecord::Migration[7.1]
  def change
    create_table :batches do |t|
      t.references :pond, null: false, foreign_key: true

      t.string :name, null: false
      t.string :species, null: true

      t.string :status, null: false, default: "active" # active/closed
      t.string :stage, null: false, default: "juvenile" # nursery/juvenile/growout

      t.date :started_on, null: false
      t.date :closed_on, null: true

      t.integer :initial_quantity, null: true
      t.integer :current_quantity, null: true

      # peso médio em gramas
      t.decimal :avg_weight_g, precision: 10, scale: 2, null: true
      t.timestamps
    end
    add_index :batches, [:pond_id, :name]
    add_index :batches, [:status, :stage]
    add_index :batches, :started_on
  end
end
