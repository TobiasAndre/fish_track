class AddPhoneToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :phone, :string
  end
end
