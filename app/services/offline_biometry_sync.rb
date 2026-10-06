# Grava as biometrias lançadas offline (tela de biometria em campo) quando o
# aparelho volta a ter internet.
#
# Cada lançamento vem com o identificador gerado no aparelho (client_uuid): se
# ele já foi gravado (ex.: a resposta do envio anterior se perdeu), não grava de
# novo e só confirma. Os campos calculados (peso médio, biomassa, ganho, GPD,
# conversão) são recalculados pelo StockingEvent, como no lançamento online.
class OfflineBiometrySync
  MAX_ENTRIES = 200
  FIELDS = %w[batch_stocking_id occurred_on volume quantity total_weight_kg feed_kg notes].freeze

  Result = Struct.new(:uuid, :status, :id, :errors, keyword_init: true) do
    def as_json(*)
      { uuid: uuid, status: status, id: id, errors: errors || [] }
    end
  end

  def initialize(entries, tenant_name:)
    @entries = Array(entries).first(MAX_ENTRIES)
    @tenant_name = tenant_name
  end

  # Na ordem das datas, para o ganho de peso e o GPD de cada uma serem
  # calculados em relação à biometria anterior.
  def call
    @entries.sort_by { |entry| [entry["occurred_on"].to_s, entry["created_at"].to_s] }.map { |entry| sync(entry) }
  end

  private

  def sync(entry)
    uuid = entry["uuid"].to_s
    return error(uuid, "Lançamento sem identificador.") unless uuid.match?(/\A[0-9a-f-]{36}\z/i)

    if entry["tenant"].present? && entry["tenant"] != @tenant_name
      return error(uuid, "Lançado em outra empresa (#{entry['tenant']}). Entre nela para enviar.")
    end

    existing = StockingEvent.find_by(client_uuid: uuid)
    return Result.new(uuid: uuid, status: "duplicate", id: existing.id) if existing

    event = StockingEvent.new(entry.slice(*FIELDS).merge("event_type" => "biometrics", "client_uuid" => uuid))
    return error(uuid, "Tanque não encontrado. Atualize os dados dos tanques e escolha de novo.") if event.batch_stocking.nil?

    # Os tanques ficam no aparelho desde o último download: o lote pode ter sido
    # encerrado nesse meio tempo.
    batch = event.batch_stocking.batch
    return error(uuid, "O lote #{batch.name} foi encerrado depois que os tanques foram baixados. A biometria não foi gravada.") unless batch.active_status?

    if event.save
      Result.new(uuid: uuid, status: "created", id: event.id)
    else
      error(uuid, *event.errors.full_messages)
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(uuid: uuid, status: "duplicate", id: StockingEvent.find_by(client_uuid: uuid)&.id)
  end

  def error(uuid, *messages)
    Result.new(uuid: uuid, status: "error", errors: messages)
  end
end
