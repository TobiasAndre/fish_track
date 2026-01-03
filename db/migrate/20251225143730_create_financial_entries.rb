class CreateFinancialEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_entries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :unit, null: true, foreign_key: true
      t.references :batch, null: true, foreign_key: true

      t.string :entry_type, null: false # expense/income
      t.string :stage, null: false, default: "general" # nursery/juvenile/growout/general

      t.date :occurred_on, null: false

      # Dinheiro em centavos (evita problemas de float)
      t.bigint :amount_cents, null: false

      t.string :description, null: false
      t.text :notes, null: true
      t.timestamps
    end
    add_index :financial_entries, [:company_id, :occurred_on]
    add_index :financial_entries, :entry_type
    add_index :financial_entries, :stage
  end
end
