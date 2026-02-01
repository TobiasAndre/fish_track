class RemoveCompanyFromFinancialEntries < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :financial_entries, :companies if foreign_key_exists?(:financial_entries, :companies)
    remove_index :financial_entries, :company_id if index_exists?(:financial_entries, :company_id)

    if index_exists?(:financial_entries, [:company_id, :occurred_on])
      remove_index :financial_entries, column: [:company_id, :occurred_on]
    end

    remove_column :financial_entries, :company_id, :bigint if column_exists?(:financial_entries, :company_id)
  end
end
