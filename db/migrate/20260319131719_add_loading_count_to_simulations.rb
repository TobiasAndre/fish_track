class AddLoadingCountToSimulations < ActiveRecord::Migration[7.1]
  def change
    add_column :simulations, :loading_count, :integer, null: false, default: 1
  end
end
