class AddFieldsToPayrollItems < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_items, :occurred_on, :date, null: false, default: -> { "CURRENT_DATE" }

    add_index :payroll_items, :occurred_on
  end
end
