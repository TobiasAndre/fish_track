class CreateStockingEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :stocking_events do |t|
      t.references :batch_stocking, null: false, foreign_key: true
      t.string :event_type, null: false
      t.date :occurred_on, null: false
      t.integer :quantity
      t.decimal :avg_weight_g, precision: 10, scale: 2
      t.decimal :feed_kg, precision: 10, scale: 3
      t.text :notes

      t.timestamps
    end

    add_index :stocking_events, :event_type
    add_index :stocking_events, :occurred_on
    add_index :stocking_events, [:batch_stocking_id, :occurred_on], name: "idx_stocking_events_on_stocking_and_date"
  end
end
