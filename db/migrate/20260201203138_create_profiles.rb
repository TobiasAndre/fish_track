class CreateProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :profiles do |t|
      t.bigint :user_id, null: false
      t.string :display_name

      t.timestamps
    end

    add_index :profiles, :user_id, unique: true
  end
end