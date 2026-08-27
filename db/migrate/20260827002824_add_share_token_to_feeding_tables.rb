class AddShareTokenToFeedingTables < ActiveRecord::Migration[7.1]
  def change
    add_column :feeding_tables, :share_token, :string
    add_index :feeding_tables, :share_token, unique: true
  end
end
