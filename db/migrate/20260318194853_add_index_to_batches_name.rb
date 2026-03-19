class AddIndexToBatchesName < ActiveRecord::Migration[7.1]
  def change
    add_index :batches, :name
  end
end
