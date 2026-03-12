class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true

      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.bigint :unit_price_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.string :unit, null: false, default: "kg"
      t.string :description

      t.timestamps
    end
  end
end
