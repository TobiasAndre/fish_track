class AddShareTokenToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :share_token, :string
    add_index :employees, :share_token, unique: true
  end
end
