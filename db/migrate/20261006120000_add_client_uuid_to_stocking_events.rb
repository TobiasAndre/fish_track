class AddClientUuidToStockingEvents < ActiveRecord::Migration[8.1]
  def change
    # Identificador gerado no aparelho para lançamentos feitos offline (biometria
    # em campo): reenviar o mesmo lançamento nunca cria um segundo registro.
    add_column :stocking_events, :client_uuid, :string
    add_index :stocking_events, :client_uuid, unique: true
  end
end
