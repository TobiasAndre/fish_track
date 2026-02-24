class CreatePonds < ActiveRecord::Migration[7.1]
  def change
    create_table :ponds do |t|
      t.references :unit, null: false, foreign_key: true
      t.string :name, null: false

      # opcional (capacidade do Tanque/tanque)
      t.decimal :capacity, precision: 12, scale: 2, null: true
      t.string :capacity_unit, null: true # ex: "m3", "ha", "liters"
      t.timestamps
    end
    add_index :ponds, [:unit_id, :name], unique: true
  end
end
