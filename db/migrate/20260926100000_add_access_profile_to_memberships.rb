class AddAccessProfileToMemberships < ActiveRecord::Migration[8.1]
  def change
    # Perfil de acesso do usuário nesta empresa. Sem FK: memberships vive no schema
    # público e access_profiles no schema de cada empresa.
    add_column :memberships, :access_profile_id, :bigint
    add_index :memberships, :access_profile_id
  end
end
