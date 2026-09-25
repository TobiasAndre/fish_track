# Localização aproximada de um IP (cidade, região, país, provedor), guardada como
# cache para não consultar o serviço externo a cada abertura de um log.
class IpLocation < ApplicationRecord
  FRESH_FOR = 30.days

  validates :ip_address, presence: true, uniqueness: true
  validates :looked_up_at, presence: true

  scope :fresh, -> { where(looked_up_at: FRESH_FOR.ago..) }

  def stale?
    looked_up_at < FRESH_FOR.ago
  end

  # "São Paulo, SP, Brasil"
  def place
    [city, region, country].compact_blank.uniq.join(", ").presence
  end
end
