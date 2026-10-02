# Configuração do backup do banco (uma linha só, no schema público): a conta e a
# pasta do Google Drive para onde os arquivos vão e o agendamento automático.
#
# O client secret e o refresh token do Google ficam cifrados (Active Record
# Encryption). O horário é sempre o de Brasília (config.time_zone).
class BackupSetting < ApplicationRecord
  include Loggable

  FREQUENCIES = { "daily" => "Diário", "weekly" => "Semanal", "monthly" => "Mensal" }.freeze
  WEEKDAYS = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado].freeze
  TIME_OF_DAY_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  encrypts :google_client_secret, :google_refresh_token

  validates :drive_folder_name, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :time_of_day, format: { with: TIME_OF_DAY_FORMAT, message: "deve estar no formato HH:MM" }
  validates :weekday, inclusion: { in: 0..6 }
  validates :month_day, inclusion: { in: 1..28, message: "deve ser entre 1 e 28" }
  validate :drive_connected_to_schedule

  before_save :reset_google_connection, if: -> { google_client_id_changed? && google_client_id_was.present? }
  before_save :forget_drive_folder, if: :drive_folder_name_changed?
  before_save :schedule_next_run

  def self.current
    first || create!
  end

  # Client ID e secret informados: dá para conectar a conta.
  def google_app_configured?
    google_client_id.present? && google_client_secret.present?
  end

  # Conta autorizada: dá para enviar arquivos.
  def drive_connected?
    google_app_configured? && google_refresh_token.present?
  end

  def drive_client
    GoogleDrive.new(client_id: google_client_id, client_secret: google_client_secret, refresh_token: google_refresh_token)
  end

  def due?(now = Time.current)
    schedule_enabled? && drive_connected? && next_run_at.present? && next_run_at <= now
  end

  # Reserva a execução agendada para quem chegar primeiro (mais de um processo
  # pode estar olhando o relógio) e já marca a próxima.
  def claim_run!(now = Time.current)
    following = next_run_after(now)
    claimed = self.class.where(id: id, next_run_at: next_run_at).update_all(next_run_at: following, updated_at: now) == 1
    self.next_run_at = following if claimed
    claimed
  end

  # Próximo horário agendado depois de `from`.
  def next_run_after(from)
    from = from.in_time_zone
    hour, minute = time_of_day.split(":").map(&:to_i)
    at = ->(date) { Time.zone.local(date.year, date.month, date.day, hour, minute) }

    case frequency
    when "weekly"
      date = from.to_date + ((weekday - from.wday) % 7)
      at.call(date) > from ? at.call(date) : at.call(date + 7)
    when "monthly"
      date = from.to_date.change(day: month_day)
      at.call(date) > from ? at.call(date) : at.call(date.next_month)
    else
      date = from.to_date
      at.call(date) > from ? at.call(date) : at.call(date + 1)
    end
  end

  # "Diário às 03:00", "Semanal (Segunda-feira) às 03:00", "Mensal (dia 5) às 03:00"
  def schedule_description
    detail = case frequency
    when "weekly" then " (#{WEEKDAYS[weekday]})"
    when "monthly" then " (dia #{month_day})"
    end

    "#{FREQUENCIES[frequency]}#{detail} às #{time_of_day}"
  end

  private

  def activity_description
    "Configuração de backup"
  end

  def drive_connected_to_schedule
    return unless schedule_enabled? && !drive_connected?

    errors.add(:schedule_enabled, "precisa do Google Drive conectado")
  end

  # A autorização pertence ao app do Google (client ID) que a gerou; sem ela o
  # agendamento não tem para onde enviar.
  def reset_google_connection
    self.schedule_enabled = false
    self.google_refresh_token = nil
    self.google_account_email = nil
    self.drive_folder_id = nil
  end

  def forget_drive_folder
    self.drive_folder_id = nil
  end

  def schedule_next_run
    return unless will_save_change_to_schedule_enabled? || will_save_change_to_frequency? ||
      will_save_change_to_time_of_day? || will_save_change_to_weekday? || will_save_change_to_month_day?

    self.next_run_at = schedule_enabled? ? next_run_after(Time.current) : nil
  end
end
