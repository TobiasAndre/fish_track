class CreateUnits < ActiveRecord::Migration[7.1]
  def change
    create_table :units do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :units, [:company_id, :name], unique: true
  end
end
