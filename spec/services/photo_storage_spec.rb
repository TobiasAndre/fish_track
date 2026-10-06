require "rails_helper"
require "tmpdir"

RSpec.describe PhotoStorage do
  let(:jpeg) { file_fixture("peixe.jpg").to_s }

  describe PhotoStorage::SquareCloud do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:sleeps) { [] }
    let(:storage) do
      connection = Faraday.new(url: "https://blob.squarecloud.app/v1/") do |f|
        f.request :multipart
        f.adapter :test, stubs
      end
      described_class.new(api_key: "chave", connection: connection, sleeper: ->(seconds) { sleeps << seconds })
    end

    def json(status, body)
      [status, { "Content-Type" => "application/json" }, body.to_json]
    end

    it "uploads with the key, the name, the folder and an unguessable URL, and returns the id and the URL" do
      stubs.post("/v1/objects") do |env|
        expect(env.request_headers["Authorization"]).to eq("chave")
        expect(env.params).to include("name" => "biometria_7", "prefix" => "fishtrack/empresa/biometrias", "security_hash" => "true")
        expect(env.body.read).to include('filename="foto.jpg"')
        json(200, status: "success", response: { id: "pub/1/fishtrack/empresa/biometrias/biometria_7-abc.jpg", url: "https://blob.squarecloud.dev/pub/1/x/biometria_7-abc.jpg" })
      end

      result = storage.upload(jpeg, filename: "foto.jpg", content_type: "image/jpeg", name: "biometria_7", prefix: "fishtrack/empresa/biometrias")

      expect(result).to eq(id: "pub/1/fishtrack/empresa/biometrias/biometria_7-abc.jpg", url: "https://blob.squarecloud.dev/pub/1/x/biometria_7-abc.jpg")
    end

    it "waits and tries again when the plan's upload rate limit is hit" do
      calls = 0
      stubs.post("/v1/objects") do
        calls += 1
        calls == 1 ? json(429, status: "error", code: "RATE_LIMITED") : json(200, status: "success", response: { id: "pub/1/a.jpg", url: "https://blob.squarecloud.dev/pub/1/a.jpg" })
      end

      expect(storage.upload(jpeg, filename: "a.jpg", content_type: "image/jpeg", name: "a", prefix: "p")[:id]).to eq("pub/1/a.jpg")
      expect(calls).to eq(2)
      expect(sleeps.size).to eq(1)
    end

    it "explains the common account problems" do
      stubs.post("/v1/objects") { json(403, status: "error", code: "MISSING_SCOPE") }

      expect { storage.upload(jpeg, filename: "a.jpg", content_type: "image/jpeg", name: "a", prefix: "p") }
        .to raise_error(PhotoStorage::Error, /escopo blob:write/)
    end

    it "deletes by id and treats an already deleted file as done" do
      stubs.delete("/v1/objects") do |env|
        expect(JSON.parse(env.body)).to eq("object" => "pub/1/a.jpg")
        json(404, status: "error", code: "OBJECT_NOT_FOUND")
      end

      expect(storage.delete("pub/1/a.jpg")).to be(true)
    end
  end

  describe ".current" do
    it "uses the local folder outside production when there is no Square Cloud key" do
      expect(described_class.current).to be_a(PhotoStorage::Local)
    end

    it "uses the Square Cloud Blob when the key is set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SQUARECLOUD_API_KEY").and_return("chave")
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("SQUARECLOUD_API_KEY").and_return("chave")

      expect(described_class.current).to be_a(PhotoStorage::SquareCloud)
    end

    it "refuses to run in production without the key, instead of losing photos on the server disk" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect { described_class.current }.to raise_error(PhotoStorage::Error, /SQUARECLOUD_API_KEY/)
    end
  end
end
