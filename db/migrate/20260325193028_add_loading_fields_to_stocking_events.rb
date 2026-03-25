class AddLoadingFieldsToStockingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :stocking_events, :price_per_kg_cents, :integer
    add_column :stocking_events, :thousand_value_cents, :integer
    add_column :stocking_events, :freight_cost_cents, :integer
    add_column :stocking_events, :loading_cost_cents, :integer
    add_column :stocking_events, :payment_date, :date
    add_column :stocking_events, :payment_method, :string

    add_reference :stocking_events, :customer, null: true, foreign_key: true
    add_reference :stocking_events, :integrated, null: true, foreign_key: true
  end
end
