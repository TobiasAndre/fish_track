class CreateBackupSettingsAndBackups < ActiveRecord::Migration[8.1]
  def change
    # Configuração única (uma linha) do backup do banco: destino no Google Drive e
    # agendamento. Vive no schema público (modelo excluído do Apartment).
    create_table :backup_settings do |t|
      t.string :google_client_id
      t.text :google_client_secret
      t.text :google_refresh_token
      t.string :google_account_email
      t.string :drive_folder_name, null: false, default: "Fish Track - Backups"
      t.string :drive_folder_id
      t.boolean :schedule_enabled, null: false, default: false
      t.string :frequency, null: false, default: "daily"
      t.string :time_of_day, null: false, default: "03:00"
      t.integer :weekday, null: false, default: 1
      t.integer :month_day, null: false, default: 1
      t.datetime :next_run_at
      t.timestamps
    end

    # Histórico de cada backup gerado (manual ou agendado).
    create_table :backups do |t|
      t.string :status, null: false, default: "pending"
      t.string :trigger, null: false
      t.string :filename
      t.bigint :size_bytes
      t.string :drive_file_id
      t.string :drive_file_url
      t.text :error_message
      t.bigint :requested_by_id
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :backups, :created_at
    add_index :backups, :status
  end
end
