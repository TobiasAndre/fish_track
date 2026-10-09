namespace :backup do
  desc "Restaura um backup da página Backup num banco recém-criado: bin/rails db:create db:schema:load && bin/rails backup:restore FILE=arquivo.sql.gz"
  task restore: :environment do
    path = ENV["FILE"].presence || abort("Informe o arquivo: bin/rails backup:restore FILE=fish_track-backup-....sql.gz")
    abort("Arquivo não encontrado: #{path}") unless File.exist?(path)

    schemas = Apartment::Tenant.switch("public") { DatabaseRestore.new(path).call }
    puts "Backup restaurado (schemas: #{schemas.join(', ')})."
  rescue DatabaseRestore::Error => e
    abort(e.message)
  end
end
