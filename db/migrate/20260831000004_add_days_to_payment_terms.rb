class AddDaysToPaymentTerms < ActiveRecord::Migration[7.1]
  def change
    add_column :payment_terms, :days, :integer
  end
end
