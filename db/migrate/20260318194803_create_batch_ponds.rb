class CreateBatchPonds < ActiveRecord::Migration[7.1]
  def change
    create_table :batch_ponds do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :pond, null: false, foreign_key: true

      t.timestamps
    end

    add_index :batch_ponds, [:batch_id, :pond_id], unique: true
  end
end
