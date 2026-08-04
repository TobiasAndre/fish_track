class AddTaxPercentageAndLoadingDestinationToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :tax_percentage, :decimal, precision: 5, scale: 2
    add_column :stocking_events, :loading_destination, :string
  end
end
