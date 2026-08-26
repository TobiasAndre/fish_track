class CreateSilos < ActiveRecord::Migration[7.1]
  def change
    create_table :silos do |t|
      t.references :unit, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :silos, "unit_id, lower(btrim(name))", unique: true, name: "index_silos_on_unit_and_normalized_name"
  end
end
