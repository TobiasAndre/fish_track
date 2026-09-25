class CreateAccessProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :access_profiles do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :access_profiles, "lower(name)", unique: true, name: "index_access_profiles_on_lower_name"

    create_table :access_profile_permissions do |t|
      t.references :access_profile, null: false, foreign_key: { on_delete: :cascade }
      t.string :resource, null: false # chave da página (ver PermissionCatalog)
      t.string :action, null: false   # read | write | edit | delete
    end

    add_index :access_profile_permissions, %i[access_profile_id resource action], unique: true, name: "index_access_profile_permissions_uniqueness"
  end
end
