class AddPayrollItemIdToFinancialEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :financial_entries, :payroll_item_id, :bigint
    add_index :financial_entries, :payroll_item_id
    add_foreign_key :financial_entries, :payroll_items
  end
end
