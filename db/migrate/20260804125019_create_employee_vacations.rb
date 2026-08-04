class CreateEmployeeVacations < ActiveRecord::Migration[7.1]
  def change
    create_table :employee_vacations do |t|
      t.references :employee, null: false, foreign_key: true

      t.date :accrual_started_on, null: false
      t.date :accrual_ended_on, null: false
      t.date :scheduled_start_on
      t.date :scheduled_end_on
      t.date :taken_start_on
      t.date :taken_end_on

      t.string :status, null: false, default: "accruing"
      t.integer :entitled_days, null: false, default: 30
      t.integer :taken_days, null: false, default: 0

      t.bigint :payment_amount_cents
      t.date :payment_due_on
      t.date :paid_on

      t.text :notes

      t.timestamps
    end

    add_index :employee_vacations, :status
    add_index :employee_vacations, :payment_due_on
    add_index :employee_vacations, [:employee_id, :accrual_started_on],
      name: "idx_employee_vacations_on_employee_and_accrual_start"
  end
end
