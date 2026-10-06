require "faraday"
require "faraday/multipart"
require "json"

module PhotoStorage
  # Blob Storage da Square Cloud (https://docs.squarecloud.app/en/blob-reference).
  #
  # Envia com security_hash: a URL é pública (abre direto num <img>), mas leva um
  # código aleatório, então não dá para adivinhar a de outra foto. Nos planos
  # Hobby/Standard o Blob aceita 1 envio por segundo: quando responde
  # RATE_LIMITED, espera e tenta de novo.
  class SquareCloud
    BASE_URL = "https://blob.squarecloud.app/v1/".freeze
    MAX_ATTEMPTS = 4
    RETRY_CODES = %w[RATE_LIMITED TOO_MANY_CONCURRENT_UPLOADS].freeze

    MESSAGES = {
      "ACCESS_DENIED" => "a chave da Square Cloud não foi aceita (SQUARECLOUD_API_KEY)",
      "MISSING_SCOPE" => "a chave da Square Cloud não tem o escopo blob:write",
      "RESOURCE_NOT_ALLOWED" => "a chave da Square Cloud está restrita a aplicações; use uma sem restrição",
      "PERMISSION_DENIED" => "a conta da Square Cloud está sem plano ativo",
      "STORAGE_QUOTA_EXCEEDED" => "o espaço do Blob da Square Cloud acabou",
      "FILE_TOO_LARGE" => "arquivo grande demais",
      "BLOCKED_FILE_TYPE" => "tipo de arquivo não aceito",
      "RATE_LIMITED" => "a Square Cloud limitou os envios; tente de novo em instantes"
    }.freeze

    def initialize(api_key: ENV.fetch("SQUARECLOUD_API_KEY"), base_url: ENV.fetch("SQUARECLOUD_BLOB_URL", BASE_URL), connection: nil, sleeper: ->(seconds) { sleep(seconds) })
      @api_key = api_key
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @connection = connection
      @sleeper = sleeper
    end

    def upload(path, filename:, content_type:, name:, prefix:)
      query = { name: PhotoStorage.safe_segment(name), prefix: prefix, security_hash: true }.to_query

      data = request do
        connection.post("objects?#{query}") do |req|
          req.headers["Authorization"] = @api_key
          req.body = { file: Faraday::Multipart::FilePart.new(path, content_type, filename) }
        end
      end

      { id: data.dig("response", "id"), url: data.dig("response", "url") }.tap do |result|
        raise Error, "O Blob da Square Cloud não devolveu o endereço da foto." if result.values.any?(&:blank?)
      end
    end

    # Apagar algo que já não existe conta como sucesso.
    def delete(id)
      request(missing_ok: true) do
        connection.delete("objects") do |req|
          req.headers["Authorization"] = @api_key
          req.headers["Content-Type"] = "application/json"
          req.body = { object: id }.to_json
        end
      end
      true
    end

    private

    def request(missing_ok: false)
      attempt = 0

      loop do
        attempt += 1
        response = yield
        data = JSON.parse(response.body.to_s) rescue {}

        return data if response.success? && data["status"] != "error"
        return data if missing_ok && response.status == 404

        code = data["code"].to_s
        if RETRY_CODES.include?(code) && attempt < MAX_ATTEMPTS
          @sleeper.call(1.1 * attempt)
          next
        end

        raise Error, "Falha ao guardar a foto: #{MESSAGES.fetch(code) { [code.presence, data['message'].presence].compact.join(': ').presence || "HTTP #{response.status}" }}."
      end
    rescue Faraday::Error => e
      raise Error, "Não foi possível falar com o Blob da Square Cloud (#{e.class.name.demodulize})."
    end

    def connection
      @connection ||= Faraday.new(url: @base_url, request: { timeout: 60, open_timeout: 10 }) do |f|
        f.request :multipart
        f.adapter Faraday.default_adapter
      end
    end
  end
end
