require "ipaddr"

# Descobre a localização aproximada de um IP (cidade, região, país, provedor).
#
# IPs locais/privados não são enviados a ninguém. Os demais são consultados num
# serviço externo (ipwho.is, HTTPS, sem chave) com timeout curto e o resultado
# fica em IpLocation por 30 dias, então cada IP é consultado no máximo uma vez
# nesse período. Se o serviço falhar, devolve nil e não grava nada: a tela mostra
# "indisponível" e tenta de novo na próxima abertura.
class IpLocator
  Result = Struct.new(:ip_address, :kind, :place, :city, :region, :country, :isp, keyword_init: true) do
    def local?
      kind == :local
    end

    def found?
      kind == :found
    end
  end

  ENDPOINT = "https://ipwho.is".freeze
  TIMEOUT_SECONDS = 3

  def initialize(connection: nil)
    @connection = connection
  end

  # Result, ou nil se o IP for vazio/inválido ou o serviço estiver indisponível.
  def locate(ip_address)
    ip = normalize(ip_address)
    return nil if ip.nil?
    return Result.new(ip_address: ip.to_s, kind: :local, place: "Rede local (sem localização pública)") if local?(ip)

    record = IpLocation.find_by(ip_address: ip.to_s)
    record = refresh(ip.to_s, record) if record.nil? || record.stale?
    record && build_result(record)
  end

  private

  def normalize(value)
    IPAddr.new(value.to_s.strip)
  rescue IPAddr::Error
    nil
  end

  def local?(ip)
    ip.loopback? || ip.private? || ip.link_local? || ip.to_s == "0.0.0.0"
  end

  def refresh(ip, existing)
    data = fetch(ip)
    return existing if data.nil? # mantém o cache antigo se o serviço falhar

    record = existing || IpLocation.new(ip_address: ip)
    record.update!(
      city: data["city"], region: data["region"], country: data["country"], country_code: data["country_code"],
      isp: data.dig("connection", "isp").presence || data.dig("connection", "org"),
      latitude: data["latitude"], longitude: data["longitude"],
      source: "ipwho.is", looked_up_at: Time.current
    )
    record
  rescue ActiveRecord::RecordNotUnique
    IpLocation.find_by(ip_address: ip)
  end

  def fetch(ip)
    response = connection.get("/#{ip}")
    return nil unless response.success?

    data = JSON.parse(response.body)
    data if data["success"] == true
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def connection
    @connection ||= Faraday.new(url: ENDPOINT, request: { timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS })
  end

  def build_result(record)
    Result.new(
      ip_address: record.ip_address, kind: :found, place: record.place, city: record.city,
      region: record.region, country: record.country, isp: record.isp
    )
  end
end
