class AddGtaNumberAndInvoiceNumberToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :gta_number, :string
    add_column :stocking_events, :invoice_number, :string
  end
end
