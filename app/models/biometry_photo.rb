# Foto de um lançamento de biometria. O arquivo fica no PhotoStorage (Blob da
# Square Cloud em produção); aqui ficam o id dele lá e o endereço para exibir.
class BiometryPhoto < ApplicationRecord
  include Loggable

  class Error < StandardError; end

  MAX_PER_EVENT = 10
  MAX_BYTES = 15.megabytes
  CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

  belongs_to :stocking_event

  validates :blob_object_id, :url, presence: true

  after_destroy_commit :delete_stored_file

  scope :in_order, -> { order(:created_at, :id) }

  # Guarda o arquivo enviado (ActionDispatch::Http::UploadedFile) e cria a foto.
  # Erros de validação ou do armazenamento viram BiometryPhoto::Error com uma
  # mensagem para o usuário.
  def self.attach!(stocking_event, upload, client_uuid: nil)
    raise Error, "arquivo vazio" if upload.blank? || upload.size.to_i.zero?
    raise Error, "#{upload.original_filename}: maior que #{MAX_BYTES / 1.megabyte} MB" if upload.size > MAX_BYTES

    # Pelo conteúdo do arquivo (sem o nome, que faria o Marcel cair na extensão).
    content_type = Marcel::MimeType.for(Pathname(upload.path))
    raise Error, "#{upload.original_filename}: não é uma imagem (JPEG, PNG, WebP ou HEIC)" unless CONTENT_TYPES.include?(content_type)

    if stocking_event.biometry_photos.count >= MAX_PER_EVENT
      raise Error, "cada biometria aceita até #{MAX_PER_EVENT} fotos"
    end

    stored = PhotoStorage.current.upload(
      upload.path,
      filename: upload.original_filename.presence || "foto.jpg",
      content_type: content_type,
      name: "biometria_#{stocking_event.id}",
      prefix: "fishtrack/#{PhotoStorage.safe_segment(Apartment::Tenant.current)}/biometrias"
    )

    create!(
      stocking_event: stocking_event, blob_object_id: stored[:id], url: stored[:url],
      filename: upload.original_filename, content_type: content_type, byte_size: upload.size, client_uuid: client_uuid
    )
  rescue PhotoStorage::Error => e
    raise Error, e.message
  end

  private

  def delete_stored_file
    PhotoStorage.current.delete(blob_object_id)
  rescue PhotoStorage::Error => e
    Rails.logger.error("[fotos] não foi possível apagar #{blob_object_id}: #{e.message}")
  end

  def activity_description
    date = stocking_event&.occurred_on ? I18n.l(stocking_event.occurred_on) : "—"
    "Foto da biometria de #{date} - #{stocking_event&.batch_stocking&.display_name}"
  end
end
