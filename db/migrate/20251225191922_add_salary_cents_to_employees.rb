class AddSalaryCentsToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :salary_cents, :bigint, null: false, default: 0
    add_index :employees, :salary_cents
  end
end
