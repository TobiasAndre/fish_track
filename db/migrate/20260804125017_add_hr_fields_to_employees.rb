class AddHrFieldsToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :department, :string
    add_column :employees, :status, :string, null: false, default: "active"
    add_column :employees, :terminated_on, :date
    add_column :employees, :notes, :text

    add_index :employees, :status
    add_index :employees, :department
  end
end
