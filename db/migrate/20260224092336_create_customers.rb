class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :tax_id
      t.string :state_registration
      t.string :email
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
