class RemoveCompanyFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :users, :companies if foreign_key_exists?(:users, :companies)
    remove_index :users, :company_id if index_exists?(:users, :company_id)
    remove_column :users, :company_id, :bigint if column_exists?(:users, :company_id)
  end
end
