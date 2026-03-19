class DropBatchEvents < ActiveRecord::Migration[7.1]
  def up
    drop_table :batch_events
  end

  def down
    create_table :batch_events do |t|
      t.bigint "batch_id", null: false
      t.string "event_type", null: false
      t.date "occurred_on", null: false
      t.integer "quantity"
      t.decimal "avg_weight_g", precision: 10, scale: 2
      t.decimal "feed_kg", precision: 10, scale: 3
      t.text "notes"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    add_index :batch_events, ["batch_id", "occurred_on"], name: "index_batch_events_on_batch_id_and_occurred_on"
    add_index :batch_events, ["batch_id"], name: "index_batch_events_on_batch_id"
    add_index :batch_events, ["event_type"], name: "index_batch_events_on_event_type"
  end
end
