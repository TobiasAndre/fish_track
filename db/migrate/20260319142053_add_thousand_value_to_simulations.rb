class AddThousandValueToSimulations < ActiveRecord::Migration[7.1]
  def change
    add_column :simulations, :thousand_value_cents, :bigint, null: false, default: 0
  end
end
