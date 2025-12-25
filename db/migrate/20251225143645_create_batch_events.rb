class CreateBatchEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :batch_events do |t|
      t.references :batch, null: false, foreign_key: true

      t.string :event_type, null: false
      t.date :occurred_on, null: false

      # campos genéricos
      t.integer :quantity, null: true

      # biometria
      t.decimal :avg_weight_g, precision: 10, scale: 2, null: true

      # alimentação / arraçoamento
      t.decimal :feed_kg, precision: 10, scale: 3, null: true

      t.text :notes, null: true

      t.timestamps
    end
    add_index :batch_events, [:batch_id, :occurred_on]
    add_index :batch_events, :event_type
  end
end
