class AddFeedFieldsToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :feed_conversion, :decimal, precision: 14, scale: 3
  end
end
