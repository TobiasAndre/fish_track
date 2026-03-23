class AddPrintSettingsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :logo_url, :string
    add_column :companies, :print_message_line_1, :string
    add_column :companies, :print_message_line_2, :string
  end
end
