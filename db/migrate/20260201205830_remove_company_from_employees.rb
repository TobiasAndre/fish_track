class RemoveCompanyFromEmployees < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :employees, :companies if foreign_key_exists?(:employees, :companies)
    remove_index :employees, :company_id if index_exists?(:employees, :company_id)

    if index_exists?(:employees, [:company_id, :name])
      remove_index :employees, column: [:company_id, :name]
    end

    remove_column :employees, :company_id, :bigint if column_exists?(:employees, :company_id)

    add_index :employees, :name unless index_exists?(:employees, :name)
  end
end
