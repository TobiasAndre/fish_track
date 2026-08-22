class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, foreign_key: true

      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id
      t.string :event_type
      t.string :description, null: false
      t.string :ip_address

      t.timestamps
    end

    add_index :activity_logs, [:resource_type, :resource_id]
    add_index :activity_logs, :created_at
  end
end
