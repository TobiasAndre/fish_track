class DropBatchPonds < ActiveRecord::Migration[7.1]
  def up
    drop_table :batch_ponds
  end

  def down
    create_table :batch_ponds do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :pond, null: false, foreign_key: true
      t.timestamps
    end
  end
end
