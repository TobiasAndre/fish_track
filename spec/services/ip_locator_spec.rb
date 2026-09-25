require "rails_helper"

RSpec.describe IpLocator do
  def connection(&stubs_block)
    stubs = Faraday::Adapter::Test::Stubs.new(&stubs_block)
    Faraday.new(url: IpLocator::ENDPOINT) { |f| f.adapter :test, stubs }
  end

  let(:ok_body) do
    { success: true, ip: "200.10.20.30", city: "São Paulo", region: "São Paulo", country: "Brasil", country_code: "BR",
      latitude: -23.55, longitude: -46.63, connection: { isp: "Vivo", org: "Telefonica" } }.to_json
  end

  it "finds the place of a public IP, keeps it and returns city, region, country and provider" do
    conn = connection { |stub| stub.get("/200.10.20.30") { [200, {}, ok_body] } }

    result = described_class.new(connection: conn).locate("200.10.20.30")

    expect(result).to be_found
    expect(result).to have_attributes(city: "São Paulo", region: "São Paulo", country: "Brasil", isp: "Vivo", place: "São Paulo, Brasil")
    expect(IpLocation.find_by(ip_address: "200.10.20.30")).to have_attributes(country_code: "BR", source: "ipwho.is", isp: "Vivo")
  end

  it "asks the service only once per IP: the second lookup comes from the cache" do
    calls = 0
    conn = connection { |stub| stub.get("/200.10.20.30") { calls += 1; [200, {}, ok_body] } }
    locator = described_class.new(connection: conn)

    2.times { locator.locate("200.10.20.30") }

    expect(calls).to eq(1)
  end

  it "refreshes a location older than 30 days" do
    IpLocation.create!(ip_address: "200.10.20.30", city: "Antiga", country: "Brasil", looked_up_at: 31.days.ago)
    conn = connection { |stub| stub.get("/200.10.20.30") { [200, {}, ok_body] } }

    result = described_class.new(connection: conn).locate("200.10.20.30")

    expect(result.city).to eq("São Paulo")
    expect(IpLocation.where(ip_address: "200.10.20.30").count).to eq(1)
    expect(IpLocation.find_by(ip_address: "200.10.20.30").looked_up_at).to be > 1.minute.ago
  end

  it "keeps using the old data when refreshing a stale location fails" do
    IpLocation.create!(ip_address: "200.10.20.30", city: "Antiga", country: "Brasil", looked_up_at: 31.days.ago)
    conn = connection { |stub| stub.get("/200.10.20.30") { [503, {}, "down"] } }

    expect(described_class.new(connection: conn).locate("200.10.20.30").city).to eq("Antiga")
  end

  %w[127.0.0.1 ::1 10.1.2.3 192.168.0.10 172.16.5.4 169.254.1.1].each do |ip|
    it "does not call the service for the local/private address #{ip}" do
      conn = connection { |_stub| } # qualquer requisição estouraria o adaptador de teste

      result = described_class.new(connection: conn).locate(ip)

      expect(result).to be_local
      expect(result.place).to include("Rede local")
      expect(IpLocation.count).to eq(0)
    end
  end

  it "returns nil and stores nothing when the service is down or answers badly" do
    [[503, "down"], [200, "not json"], [200, { success: false, message: "Reserved range" }.to_json]].each do |status, body|
      conn = connection { |stub| stub.get("/200.10.20.30") { [status, {}, body] } }

      expect(described_class.new(connection: conn).locate("200.10.20.30")).to be_nil
    end
    expect(IpLocation.count).to eq(0)
  end

  it "returns nil on a timeout or connection failure" do
    conn = connection { |stub| stub.get("/200.10.20.30") { raise Faraday::TimeoutError } }

    expect(described_class.new(connection: conn).locate("200.10.20.30")).to be_nil
  end

  it "returns nil for a blank or invalid IP without calling the service" do
    locator = described_class.new(connection: connection { |_stub| })

    expect([nil, "", "  ", "not-an-ip", "999.1.1.1"].map { |ip| locator.locate(ip) }).to all(be_nil)
  end

  it "handles IPv6 addresses" do
    ipv6 = "2804:14d:1234::1"
    conn = connection { |stub| stub.get("/#{ipv6}") { [200, {}, ok_body] } }

    expect(described_class.new(connection: conn).locate(ipv6)).to be_found
  end
end

RSpec.describe IpLocation do
  it "builds the place from city, region and country without repeating names" do
    expect(described_class.new(city: "São Paulo", region: "São Paulo", country: "Brasil").place).to eq("São Paulo, Brasil")
    expect(described_class.new(city: "Recife", region: "PE", country: "Brasil").place).to eq("Recife, PE, Brasil")
    expect(described_class.new(country: "Brasil").place).to eq("Brasil")
    expect(described_class.new.place).to be_nil
  end

  it "flags a stale lookup" do
    expect(described_class.new(looked_up_at: 31.days.ago)).to be_stale
    expect(described_class.new(looked_up_at: 1.day.ago)).not_to be_stale
  end
end
