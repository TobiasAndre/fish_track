class AddProductToBatches < ActiveRecord::Migration[7.1]
  def change
    add_reference :batches, :product, foreign_key: true
  end
end
