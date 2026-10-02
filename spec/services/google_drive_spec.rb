require "rails_helper"
require "tmpdir"

RSpec.describe GoogleDrive do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) { Faraday.new { |f| f.adapter :test, stubs } }
  let(:drive) { described_class.new(client_id: "client", client_secret: "secret", refresh_token: "refresh", connection: connection) }

  def json(status, body, headers = {})
    [status, { "Content-Type" => "application/json" }.merge(headers), body.to_json]
  end

  before do
    stubs.post("https://oauth2.googleapis.com/token") do |env|
      form = URI.decode_www_form(env.body).to_h
      form["grant_type"] == "refresh_token" && form["refresh_token"] == "refresh" ? json(200, access_token: "access") : json(400, error: "invalid_grant")
    end
  end

  it "builds the consent URL asking for offline access to the files the app creates" do
    url = described_class.authorization_url(client_id: "client", redirect_uri: "https://app.test/callback", state: "xyz")
    query = Rack::Utils.parse_query(URI(url).query)

    expect(url).to start_with(GoogleDrive::AUTH_URL)
    expect(query).to include("client_id" => "client", "redirect_uri" => "https://app.test/callback", "state" => "xyz",
      "scope" => GoogleDrive::SCOPE, "access_type" => "offline", "prompt" => "consent", "response_type" => "code")
  end

  it "exchanges the authorization code for a refresh token" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("https://oauth2.googleapis.com/token") do |env|
      form = URI.decode_www_form(env.body).to_h
      expect(form).to include("code" => "the-code", "grant_type" => "authorization_code", "redirect_uri" => "https://app.test/callback")
      json(200, access_token: "access", refresh_token: "new-refresh")
    end
    drive = described_class.new(client_id: "client", client_secret: "secret", connection: Faraday.new { |f| f.adapter :test, stubs })

    expect(drive.exchange_code!(code: "the-code", redirect_uri: "https://app.test/callback")).to eq("new-refresh")
  end

  it "reads the account e-mail" do
    stubs.get("https://www.googleapis.com/drive/v3/about") do |env|
      expect(env.request_headers["Authorization"]).to eq("Bearer access")
      json(200, user: { emailAddress: "backup@example.com" })
    end

    expect(drive.account_email).to eq("backup@example.com")
  end

  describe "#ensure_folder" do
    it "keeps a folder that still exists" do
      stubs.get("https://www.googleapis.com/drive/v3/files/folder-1") { json(200, id: "folder-1", trashed: false) }

      expect(drive.ensure_folder(id: "folder-1", name: "Backups")).to eq("folder-1")
    end

    it "creates the folder when there is none yet or the old one is gone" do
      stubs.get("https://www.googleapis.com/drive/v3/files/gone") { json(404, error: { message: "File not found" }) }
      stubs.post("https://www.googleapis.com/drive/v3/files") do |env|
        expect(JSON.parse(env.body)).to eq("name" => "Backups", "mimeType" => GoogleDrive::FOLDER_MIME_TYPE)
        json(200, id: "new-folder")
      end

      expect(drive.ensure_folder(id: "gone", name: "Backups")).to eq("new-folder")
      expect(drive.ensure_folder(id: nil, name: "Backups")).to eq("new-folder")
    end
  end

  it "uploads the file into the folder with a resumable upload" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "backup.sql.gz")
      File.binwrite(path, "conteudo")

      stubs.post("https://www.googleapis.com/upload/drive/v3/files") do |env|
        expect(env.params).to include("uploadType" => "resumable")
        expect(JSON.parse(env.body)).to eq("name" => "backup.sql.gz", "parents" => ["folder-1"])
        expect(env.request_headers["X-Upload-Content-Length"]).to eq("8")
        [200, { "Location" => "https://www.googleapis.com/upload/session-1" }, ""]
      end
      stubs.put("https://www.googleapis.com/upload/session-1") do |env|
        body = env.body.respond_to?(:read) ? env.body.read : env.body
        expect(body).to eq("conteudo")
        json(200, id: "file-1", webViewLink: "https://drive.google.com/file/d/file-1/view")
      end

      expect(drive.upload(path, name: "backup.sql.gz", folder_id: "folder-1"))
        .to eq(id: "file-1", url: "https://drive.google.com/file/d/file-1/view")
    end
  end

  it "explains when the authorization was revoked or expired" do
    revoked = described_class.new(client_id: "client", client_secret: "secret", refresh_token: "revoked", connection: connection)

    expect { revoked.account_email }.to raise_error(GoogleDrive::Error, /Conecte a conta de novo/)
  end

  it "reports Google's error message" do
    stubs.get("https://www.googleapis.com/drive/v3/about") { json(403, error: { message: "Google Drive API has not been used in project" }) }

    expect { drive.account_email }.to raise_error(GoogleDrive::Error, "Google Drive respondeu 403: Google Drive API has not been used in project")
  end
end
