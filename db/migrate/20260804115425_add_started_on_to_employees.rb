class AddStartedOnToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :started_on, :date, null: false, default: -> { "CURRENT_DATE" }
  end
end
