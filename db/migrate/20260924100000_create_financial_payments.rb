class CreateFinancialPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_payments do |t|
      # cascade: alguns fluxos (estoque de ração, folha) removem lançamentos com
      # delete_all, sem passar pelos callbacks do Rails.
      t.references :financial_entry, null: false, foreign_key: { on_delete: :cascade }
      t.date :paid_on, null: false
      t.bigint :amount_cents, null: false
      t.text :notes

      t.timestamps
    end

    add_index :financial_payments, :paid_on

    add_column :financial_entries, :paid_cents, :bigint, null: false, default: 0
  end
end
