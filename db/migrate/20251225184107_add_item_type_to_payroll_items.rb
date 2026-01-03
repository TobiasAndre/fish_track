class AddItemTypeToPayrollItems < ActiveRecord::Migration[7.1]
  def change
    add_column :payroll_items, :item_type, :string, null: false, default: "salary"
  end
end
