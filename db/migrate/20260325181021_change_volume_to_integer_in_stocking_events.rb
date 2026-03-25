class ChangeVolumeToIntegerInStockingEvents < ActiveRecord::Migration[7.1]
  def up
    change_column :stocking_events, :volume, :integer, using: "volume::integer"
  end

  def down
    change_column :stocking_events, :volume, :decimal
  end
end
