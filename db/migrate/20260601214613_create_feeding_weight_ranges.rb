class CreateFeedingWeightRanges < ActiveRecord::Migration[7.1]
  def change
    create_table :feeding_weight_ranges do |t|
      t.decimal :weight_from, precision: 10, scale: 2, null: false
      t.decimal :weight_to, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :feeding_weight_ranges,
              [:weight_from, :weight_to],
              unique: true,
              name: "idx_feeding_weight_ranges"
  end
end