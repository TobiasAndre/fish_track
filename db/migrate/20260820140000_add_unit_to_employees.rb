class AddUnitToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_reference :employees, :unit, null: true, foreign_key: true
  end
end
