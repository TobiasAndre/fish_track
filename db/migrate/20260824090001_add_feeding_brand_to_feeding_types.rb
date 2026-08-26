class AddFeedingBrandToFeedingTypes < ActiveRecord::Migration[7.1]
  def change
    add_reference :feeding_types, :feeding_brand, null: false, foreign_key: true

    remove_index :feeding_types, name: "index_feeding_types_on_normalized_name"
    add_index :feeding_types, "feeding_brand_id, lower(btrim(name))", unique: true, name: "index_feeding_types_on_brand_and_normalized_name"
  end
end
