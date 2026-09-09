require "rails_helper"

RSpec.describe SquareBlobUploader do
  around do |example|
    ENV["SQUARE_BLOB_UPLOAD_URL"] = "https://blob.example.test/upload"
    ENV["SQUARECLOUD_API_KEY"] = "test-key"
    example.run
  ensure
    ENV.delete("SQUARE_BLOB_UPLOAD_URL")
    ENV.delete("SQUARECLOUD_API_KEY")
  end

  let(:file) do
    Tempfile.new(["logo", ".png"]).tap { |f| f.write("fake-bytes"); f.rewind }
  end

  after { file.close! }

  def stub_connection(response_body:)
    conn = instance_double(Faraday::Connection)
    response = instance_double(Faraday::Response, body: response_body)
    allow(Faraday).to receive(:new).and_return(conn)
    allow(conn).to receive(:post).and_return(response)
    conn
  end

  it "posts the file to the configured endpoint and returns the URL from the response" do
    conn = stub_connection(response_body: { url: "https://cdn.example.test/logo.png" }.to_json)

    result = described_class.call(file: file, filename: "logo.png", content_type: "image/png")

    expect(result).to eq("https://cdn.example.test/logo.png")
    expect(conn).to have_received(:post).with("https://blob.example.test/upload")
  end

  it "reads the URL from a nested data hash" do
    stub_connection(response_body: { data: { url: "https://cdn.example.test/nested.png" } }.to_json)

    result = described_class.call(file: file)

    expect(result).to eq("https://cdn.example.test/nested.png")
  end

  it "raises UploadError when the response has no URL" do
    stub_connection(response_body: { status: "ok" }.to_json)

    expect { described_class.call(file: file) }
      .to raise_error(SquareBlobUploader::UploadError, /sem URL/)
  end

  it "raises UploadError when the response body is not valid JSON" do
    stub_connection(response_body: "<html>oops</html>")

    expect { described_class.call(file: file) }
      .to raise_error(SquareBlobUploader::UploadError, /Resposta inválida/)
  end

  it "wraps Faraday errors in UploadError" do
    conn = instance_double(Faraday::Connection)
    allow(Faraday).to receive(:new).and_return(conn)
    allow(conn).to receive(:post).and_raise(Faraday::ConnectionFailed.new("boom"))

    expect { described_class.call(file: file) }
      .to raise_error(SquareBlobUploader::UploadError, /Falha no upload/)
  end
end
