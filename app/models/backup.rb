# Um backup do banco gerado pela página Backup: manual (botão) ou agendado.
# Guarda o resultado do envio ao Google Drive ou o erro que impediu o envio.
class Backup < ApplicationRecord
  STATUSES = { "pending" => "Na fila", "running" => "Em andamento", "succeeded" => "Concluído", "failed" => "Falhou" }.freeze
  TRIGGERS = { "manual" => "Manual", "scheduled" => "Agendado" }.freeze

  # Um backup que não terminou nesse prazo foi interrompido (ex.: o servidor reiniciou).
  STALE_AFTER = 2.hours

  belongs_to :requested_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES.keys }
  validates :trigger, inclusion: { in: TRIGGERS.keys }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unfinished, -> { where(status: %w[pending running]) }
  scope :in_progress, -> { unfinished.where(created_at: STALE_AFTER.ago..) }

  def self.fail_stale!
    unfinished.where(created_at: ...STALE_AFTER.ago)
      .update_all(status: "failed", error_message: "Interrompido antes de terminar (o servidor pode ter reiniciado).", finished_at: Time.current)
  end

  def status_label
    STATUSES[status]
  end

  def trigger_label
    TRIGGERS[trigger]
  end

  def succeeded?
    status == "succeeded"
  end

  def failed?
    status == "failed"
  end
end
