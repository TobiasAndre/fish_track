class CreatePaymentMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_methods do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :payment_methods, :name
    add_index :payment_methods, :active
  end
end
