class CreateFeedingTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_types do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :feeding_types, "lower(btrim(name))", unique: true, name: "index_feeding_types_on_normalized_name"
  end
end
