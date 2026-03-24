class AddIntegratedToSimulations < ActiveRecord::Migration[7.1]
  def change
    add_reference :simulations, :integrated, foreign_key: true, null: true
  end
end
