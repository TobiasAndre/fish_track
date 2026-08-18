class AddTotalCentsToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :total_cents, :bigint, default: 0, null: false
  end
end
