class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true

      t.string :status, null: false, default: "draft" # draft | confirmed | delivered | canceled
      t.date :occurred_on, null: false, default: -> { "CURRENT_DATE" }

      t.bigint :total_cents, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :orders, :status
    add_index :orders, :occurred_on
  end
end
