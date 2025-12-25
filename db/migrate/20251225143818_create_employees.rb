class CreateEmployees < ActiveRecord::Migration[7.1]
  def change
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true

      t.string :name, null: false
      t.string :role, null: true # opcional (cargo)
      t.timestamps
    end
    add_index :employees, [:company_id, :name]
  end
end
