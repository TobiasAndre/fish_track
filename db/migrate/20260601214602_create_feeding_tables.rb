class CreateFeedingTables < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_tables do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :feeding_tables, :name, unique: true
  end
end