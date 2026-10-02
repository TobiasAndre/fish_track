# Liga o agendador de backups automáticos quando o servidor web sobe (ver BackupScheduler).
Rails.application.config.after_initialize do
  BackupScheduler.start if BackupScheduler.enabled?
end
