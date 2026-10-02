# Backup manual (botão da página Backup), executado em background.
class BackupJob < ApplicationJob
  queue_as :default

  def perform(backup_id)
    Apartment::Tenant.switch("public") do
      BackupRunner.new(Backup.find(backup_id)).call
    end
  end
end
