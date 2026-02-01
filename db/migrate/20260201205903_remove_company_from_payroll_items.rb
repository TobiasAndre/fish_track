class RemoveCompanyFromPayrollItems < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :payroll_items, :companies if foreign_key_exists?(:payroll_items, :companies)
    remove_index :payroll_items, :company_id if index_exists?(:payroll_items, :company_id)

    if index_exists?(:payroll_items, [:company_id, :year, :month])
      remove_index :payroll_items, column: [:company_id, :year, :month]
    end

    remove_column :payroll_items, :company_id, :bigint if column_exists?(:payroll_items, :company_id)

    add_index :payroll_items, [:year, :month] unless index_exists?(:payroll_items, [:year, :month])
  end
end
