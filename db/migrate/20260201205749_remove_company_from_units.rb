class RemoveCompanyFromUnits < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :units, :companies if foreign_key_exists?(:units, :companies)
    remove_index :units, :company_id if index_exists?(:units, :company_id)

    if index_exists?(:units, [:company_id, :name])
      remove_index :units, column: [:company_id, :name]
    end

    remove_column :units, :company_id, :bigint if column_exists?(:units, :company_id)

    add_index :units, :name, unique: true unless index_exists?(:units, :name, unique: true)
  end
end
