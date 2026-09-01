class AddInstallmentFieldsToPaymentTerms < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_terms, :installments_count, :integer, null: false, default: 1
    add_column :payment_terms, :interval_days, :integer, null: false, default: 0
    add_column :payment_terms, :day_offsets, :jsonb, null: false, default: []
  end
end
