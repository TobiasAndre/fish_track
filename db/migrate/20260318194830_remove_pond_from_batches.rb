class RemovePondFromBatches < ActiveRecord::Migration[7.1]
  def change
    remove_reference :batches, :pond, null: false, foreign_key: true
  end
end
