require "faraday"
require "json"

# Acesso ao Google Drive de uma conta autorizada por OAuth (fluxo "web server"):
# o administrador cria um app no Google Cloud, informa o client ID/secret na
# página Backup e autoriza a conta; guardamos só o refresh token.
#
# O escopo é o drive.file: o app enxerga apenas os arquivos e pastas que ele
# mesmo criou, nunca o resto do Drive da conta.
class GoogleDrive
  class Error < StandardError; end

  AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  REVOKE_URL = "https://oauth2.googleapis.com/revoke".freeze
  FILES_URL = "https://www.googleapis.com/drive/v3/files".freeze
  ABOUT_URL = "https://www.googleapis.com/drive/v3/about".freeze
  UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files".freeze
  SCOPE = "https://www.googleapis.com/auth/drive.file".freeze
  FOLDER_MIME_TYPE = "application/vnd.google-apps.folder".freeze
  TIMEOUT_SECONDS = 600

  # Endereço da tela de consentimento do Google. `prompt=consent` garante que o
  # Google devolva um refresh token mesmo se a conta já tiver autorizado antes.
  def self.authorization_url(client_id:, redirect_uri:, state:)
    query = {
      client_id: client_id, redirect_uri: redirect_uri, response_type: "code", scope: SCOPE,
      access_type: "offline", prompt: "consent", include_granted_scopes: "true", state: state
    }
    "#{AUTH_URL}?#{query.to_query}"
  end

  def initialize(client_id:, client_secret:, refresh_token: nil, connection: nil)
    @client_id = client_id
    @client_secret = client_secret
    @refresh_token = refresh_token
    @connection = connection
  end

  # Troca o código devolvido pelo Google pelo refresh token, que passa a ser o
  # desta instância e é devolvido para ser guardado.
  def exchange_code!(code:, redirect_uri:)
    data = post_form(TOKEN_URL,
      code: code, client_id: @client_id, client_secret: @client_secret, redirect_uri: redirect_uri, grant_type: "authorization_code")

    raise Error, "O Google não devolveu um refresh token. Remova o acesso do app na conta Google e conecte de novo." if data["refresh_token"].blank?

    @access_token = data["access_token"]
    @refresh_token = data["refresh_token"]
  end

  def account_email
    get_json(ABOUT_URL, fields: "user(emailAddress)").dig("user", "emailAddress")
  end

  # Id da pasta de backups: a já conhecida, se ainda existir, ou uma nova.
  def ensure_folder(id:, name:)
    if id.present?
      response = connection.get("#{FILES_URL}/#{id}", { fields: "id,trashed" }, auth_headers)
      return id if response.success? && !JSON.parse(response.body)["trashed"]
      raise_error(response) unless response.status == 404
    end

    post_json(FILES_URL, { name: name, mimeType: FOLDER_MIME_TYPE }, fields: "id")["id"]
  end

  # Envia o arquivo (upload resumível, em uma parte só) e devolve id e link.
  def upload(path, name:, folder_id:, content_type: "application/gzip")
    size = File.size(path)

    start = connection.post("#{UPLOAD_URL}?#{{ uploadType: 'resumable', fields: 'id,webViewLink' }.to_query}") do |req|
      req.headers.update(auth_headers)
      req.headers["Content-Type"] = "application/json; charset=UTF-8"
      req.headers["X-Upload-Content-Type"] = content_type
      req.headers["X-Upload-Content-Length"] = size.to_s
      req.body = { name: name, parents: [folder_id].compact }.to_json
    end
    raise_error(start) unless start.success?

    session_url = start.headers["location"]
    raise Error, "O Google Drive não abriu a sessão de upload." if session_url.blank?

    File.open(path, "rb") do |file|
      response = connection.put(session_url) do |req|
        req.headers["Content-Type"] = content_type
        req.headers["Content-Length"] = size.to_s
        req.body = file
      end
      raise_error(response) unless response.success?

      data = JSON.parse(response.body)
      { id: data["id"], url: data["webViewLink"] }
    end
  end

  # Revoga a autorização na conta Google (ao desconectar). Falhas são ignoradas:
  # o token é apagado do nosso lado de qualquer jeito.
  def revoke!
    connection.post(REVOKE_URL, URI.encode_www_form(token: @refresh_token), "Content-Type" => "application/x-www-form-urlencoded")
  rescue Faraday::Error
    nil
  end

  private

  def access_token
    @access_token ||= post_form(TOKEN_URL,
      client_id: @client_id, client_secret: @client_secret, refresh_token: @refresh_token, grant_type: "refresh_token")["access_token"]
  end

  def auth_headers
    { "Authorization" => "Bearer #{access_token}" }
  end

  def get_json(url, params)
    response = connection.get(url, params, auth_headers)
    raise_error(response) unless response.success?

    JSON.parse(response.body)
  end

  def post_json(url, body, params)
    response = connection.post("#{url}?#{params.to_query}", body.to_json, auth_headers.merge("Content-Type" => "application/json"))
    raise_error(response) unless response.success?

    JSON.parse(response.body)
  end

  def post_form(url, form)
    response = connection.post(url, URI.encode_www_form(form), "Content-Type" => "application/x-www-form-urlencoded")
    raise_error(response) unless response.success?

    JSON.parse(response.body)
  end

  def raise_error(response)
    data = JSON.parse(response.body.to_s) rescue {}
    error = data["error"]

    if error == "invalid_grant"
      raise Error, "A autorização do Google expirou ou foi revogada. Conecte a conta de novo."
    end

    message = error.is_a?(Hash) ? error["message"] : [error, data["error_description"]].compact.join(": ")
    raise Error, "Google Drive respondeu #{response.status}#{": #{message}" if message.present?}"
  end

  def connection
    @connection ||= Faraday.new(request: { timeout: TIMEOUT_SECONDS, open_timeout: 15 })
  end
end
