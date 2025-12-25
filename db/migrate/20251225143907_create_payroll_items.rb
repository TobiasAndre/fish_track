class CreatePayrollItems < ActiveRecord::Migration[7.1]
  def change
    create_table :payroll_items do |t|
      t.references :company, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true

      t.integer :year, null: false
      t.integer :month, null: false

      t.bigint :amount_cents, null: false
      t.text :notes, null: true
      t.timestamps
    end
    add_index :payroll_items, [:company_id, :year, :month]
  end
end
