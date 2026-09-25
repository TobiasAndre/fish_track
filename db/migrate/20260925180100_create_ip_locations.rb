class CreateIpLocations < ActiveRecord::Migration[8.1]
  def change
    # Cache das consultas de localização por IP (uma por IP, renovada de tempos em tempos).
    create_table :ip_locations do |t|
      t.string :ip_address, null: false
      t.string :city
      t.string :region
      t.string :country
      t.string :country_code
      t.string :isp
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.string :source
      t.datetime :looked_up_at, null: false

      t.timestamps
    end

    add_index :ip_locations, :ip_address, unique: true
  end
end
