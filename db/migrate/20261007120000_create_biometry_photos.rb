class CreateBiometryPhotos < ActiveRecord::Migration[8.1]
  def change
    # Fotos de um lançamento de biometria. O arquivo fica no Blob da Square Cloud
    # (blob_object_id é o id lá, para poder apagar; url é o endereço público, com
    # um código aleatório que impede adivinhar). client_uuid identifica a foto
    # tirada offline, para reenviar sem duplicar.
    create_table :biometry_photos do |t|
      t.references :stocking_event, null: false, foreign_key: { on_delete: :cascade }
      t.string :blob_object_id, null: false
      t.string :url, null: false
      t.string :filename
      t.string :content_type
      t.integer :byte_size
      t.string :client_uuid
      t.timestamps
    end
    add_index :biometry_photos, :client_uuid, unique: true
  end
end
