class CreateProducts < ActiveRecord::Migration[7.1]
  def change  
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku
      t.string :unit, null: false, default: "kg"
      t.boolean :active, null: false, default: true
      t.text :description

      t.timestamps
    end

    add_index :products, :name
    add_index :products, :sku, unique: true
    add_index :products, :active
  end
end
