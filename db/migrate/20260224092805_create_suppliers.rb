class CreateSuppliers < ActiveRecord::Migration[7.1]
  def change
    create_table :suppliers do |t|
      t.string :name
      t.string :tax_id
      t.string :email
      t.string :state_registration
      t.string :address
      t.string :address_number
      t.string :address_complement
      t.string :neighborhood
      t.string :postal_code
      t.string :city
      t.string :state
      t.timestamps
    end
  end
end
