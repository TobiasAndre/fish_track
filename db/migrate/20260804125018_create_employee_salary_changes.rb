class CreateEmployeeSalaryChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :employee_salary_changes do |t|
      t.references :employee, null: false, foreign_key: true

      t.bigint :previous_salary_cents
      t.bigint :salary_cents, null: false
      t.date :effective_on, null: false
      t.string :change_type, null: false
      t.text :reason

      # users live in the public schema (see Profile#user_id), so this is a
      # plain column + index, not a DB-level foreign key across schemas.
      t.bigint :created_by_id

      t.timestamps
    end

    add_index :employee_salary_changes, :effective_on
    add_index :employee_salary_changes, :change_type
    add_index :employee_salary_changes, :created_by_id
    add_index :employee_salary_changes, [:employee_id, :effective_on],
      name: "idx_employee_salary_changes_on_employee_and_effective_on"
  end
end
