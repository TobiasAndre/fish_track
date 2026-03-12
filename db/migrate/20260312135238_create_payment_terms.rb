class CreatePaymentTerms < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_terms do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :payment_terms, :name, unique: true
    add_index :payment_terms, :active
  end
end
