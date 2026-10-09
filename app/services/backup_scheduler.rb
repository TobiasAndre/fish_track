# Dispara os backups automáticos no horário configurado na página Backup.
#
# O app não tem fila de jobs nem cron no servidor, então o agendador é uma
# thread dentro do próprio processo do servidor web que olha a configuração a
# cada minuto. Se o servidor estiver fora do ar no horário, o backup roda assim
# que ele voltar. Com mais de um processo, a execução é reservada no banco
# (BackupSetting#claim_run!), então cada horário roda uma vez só.
class BackupScheduler
  INTERVAL_SECONDS = 60

  class << self
    # Só no servidor web (não em console, rake ou testes). BACKUP_SCHEDULER=off
    # desliga; BACKUP_SCHEDULER=on força (ex.: servidor iniciado sem `rails s`).
    def enabled?
      return false if Rails.env.test?

      case ENV["BACKUP_SCHEDULER"]
      when "off" then false
      when "on" then true
      else defined?(Rails::Server).present?
      end
    end

    def start
      return if @thread&.alive?

      Rails.logger.info("[backup] agendador de backups automáticos iniciado")

      @thread = Thread.new do
        Thread.current.name = "backup-scheduler"

        loop do
          sleep INTERVAL_SECONDS

          begin
            Rails.application.reloader.wrap do
              Apartment::Tenant.switch("public") { BackupScheduler.new.tick }
            end
          rescue StandardError => e
            Rails.logger.error("[backup] agendador: #{e.class}: #{e.message}")
          end
        end
      end
    end
  end

  def tick(now = Time.current)
    Backup.fail_stale!

    setting = BackupSetting.first
    return unless setting&.due?(now)
    return unless setting.claim_run!(now)

    BackupRunner.new(Backup.create!(trigger: "scheduled"), setting: setting).call
  end
end
