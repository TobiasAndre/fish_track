class AddFeedCalibrationToPonds < ActiveRecord::Migration[7.1]
  def change
    add_column :ponds, :feed_sample_kg, :decimal, precision: 10, scale: 3
    add_column :ponds, :feed_sample_seconds, :decimal, precision: 10, scale: 2
  end
end
