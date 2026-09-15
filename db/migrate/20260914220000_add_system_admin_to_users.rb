class AddSystemAdminToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :system_admin, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE users SET system_admin = true WHERE email = 'admin@fishtrack.com'
    SQL
  end

  def down
    remove_column :users, :system_admin
  end
end
