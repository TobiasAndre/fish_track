class AddFeedingFieldsToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :stocking_events, :feeding_type, null: true, foreign_key: true
    add_reference :stocking_events, :feeding_brand, null: true, foreign_key: true
  end
end
