class CreateIntegrateds < ActiveRecord::Migration[7.1]
  def change
    create_table :integrateds do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :tax_id
      t.string :state_registration
      t.string :email
      t.string :phone
      t.string :postal_code
      t.string :address
      t.string :address_number
      t.string :address_complement
      t.string :neighborhood
      t.string :city
      t.string :state
      t.text :notes

      t.timestamps
    end

    add_index :integrateds, :name
    add_index :integrateds, :tax_id
    add_index :integrateds, [:customer_id, :name]
  end
end
