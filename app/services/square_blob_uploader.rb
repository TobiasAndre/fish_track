require "faraday"
require "faraday/multipart"
require "json"

class SquareBlobUploader
  class UploadError < StandardError; end

  ENDPOINT = ENV.fetch("SQUARE_BLOB_UPLOAD_URL")
  API_KEY  = ENV.fetch("SQUARECLOUD_API_KEY")

  def self.call(file:, filename: nil, content_type: nil)
    new(file:, filename:, content_type:).call
  end

  def initialize(file:, filename: nil, content_type: nil)
    @file = file
    @filename = filename || default_filename
    @content_type = content_type || default_content_type
  end

  def call
    conn = Faraday.new do |f|
      f.request :multipart
      f.request :url_encoded
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    file_io = if @file.respond_to?(:tempfile)
      @file.tempfile
    else
      @file
    end

    payload = {
      file: Faraday::Multipart::FilePart.new(file_io.path, @content_type, @filename)
    }

    response = conn.post(ENDPOINT) do |req|
      req.headers["Authorization"] = API_KEY
      req.body = payload
    end

    data = JSON.parse(response.body)

    # ajuste estas chaves quando você confirmar a resposta real da API
    url = data["url"] || data["data"]&.[]("url") || data["file"]&.[]("url")

    raise UploadError, "Upload concluído sem URL retornada" if url.blank?

    url
  rescue Faraday::Error => e
    raise UploadError, "Falha no upload da logomarca: #{e.message}"
  rescue JSON::ParserError
    raise UploadError, "Resposta inválida do serviço de upload"
  end

  private

  def default_filename
    return @file.original_filename if @file.respond_to?(:original_filename)

    "upload.bin"
  end

  def default_content_type
    return @file.content_type if @file.respond_to?(:content_type)

    "application/octet-stream"
  end
end
