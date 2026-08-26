class AddInstallmentFieldsToPayrollItems < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_items, :installment_number, :integer
    add_column :payroll_items, :installments_count, :integer
  end
end
