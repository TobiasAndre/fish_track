class AddTenantNameToCompany < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :tenant_name, :string, null: false, default: ""
    add_index :companies, :tenant_name, unique: true
  end
end
