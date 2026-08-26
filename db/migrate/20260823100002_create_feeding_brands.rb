class CreateFeedingBrands < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_brands do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :feeding_brands, "lower(btrim(name))", unique: true, name: "index_feeding_brands_on_normalized_name"
  end
end
