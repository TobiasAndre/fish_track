class AddShareTokenToSimulations < ActiveRecord::Migration[7.1]
  def change
    add_column :simulations, :share_token, :string
    add_index :simulations, :share_token, unique: true
  end
end
