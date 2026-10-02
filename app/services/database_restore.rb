require "zlib"

# Restaura um arquivo gerado por DatabaseBackup num banco com a estrutura já
# criada e sem dados (bin/rails db:create db:schema:load). Cria o schema de cada
# empresa que estiver no arquivo e carrega os dados de todas as tabelas, numa
# transação só: se algo falhar, nada fica pela metade.
class DatabaseRestore
  class Error < StandardError; end

  def initialize(path, connection: ActiveRecord::Base.connection)
    @path = path
    @connection = connection
  end

  # Devolve os schemas restaurados.
  def call
    info = read_header
    check_schema_version!(info[:version])

    schemas = info[:schemas]
    schemas.each { |schema| create_tenant(schema) }
    ensure_empty!(schemas)

    connection.transaction { load_data }
    schemas
  end

  private

  attr_reader :path, :connection

  def read_header
    info = {}

    Zlib::GzipReader.open(path) do |gz|
      raise Error, "#{path} não é um backup do Fish Track." unless gz.gets&.chomp == DatabaseBackup::TITLE

      gz.each_line do |line|
        break unless line.start_with?("--")

        key, value = line.delete_prefix("-- ").chomp.split(": ", 2)
        info[:version] = value if key == "versao_schema"
        info[:schemas] = value.split(",") if key == "schemas"
      end
    end

    raise Error, "Cabeçalho do backup incompleto." if info[:schemas].blank?

    info
  rescue Zlib::GzipFile::Error
    raise Error, "#{path} não é um arquivo .gz válido."
  end

  # Colunas que deixaram de existir quebrariam a carga: o banco precisa estar
  # na mesma versão (ou mais nova) das migrations do backup.
  def check_schema_version!(version)
    current = connection.select_value("SELECT MAX(version) FROM schema_migrations")
    return if version.blank? || current.to_s >= version.to_s

    raise Error, "O backup é da versão #{version} do banco e este está na #{current}. Atualize o código e rode as migrations antes."
  end

  def create_tenant(schema)
    return if schema == "public"
    return if connection.select_value(ActiveRecord::Base.sanitize_sql_array(["SELECT 1 FROM pg_namespace WHERE nspname = ?", schema]))

    Apartment::Tenant.create(schema)
  end

  def ensure_empty!(schemas)
    schemas.each do |schema|
      tables = connection.select_values(ActiveRecord::Base.sanitize_sql_array(["SELECT tablename FROM pg_tables WHERE schemaname = ?", schema]))

      (tables - DatabaseBackup::SKIPPED_TABLES).each do |table|
        qualified = "#{PG::Connection.quote_ident(schema)}.#{PG::Connection.quote_ident(table)}"
        next unless connection.select_value("SELECT 1 FROM #{qualified} LIMIT 1")

        raise Error, "A tabela #{schema}.#{table} já tem dados. Restaure num banco recém-criado (bin/rails db:create db:schema:load)."
      end
    end
  end

  def load_data
    raw = connection.raw_connection

    Zlib::GzipReader.open(path) do |gz|
      while (line = gz.gets)
        if line.start_with?("COPY ")
          raw.copy_data(line.chomp.delete_suffix(";")) do
            while (row = gz.gets) && row != "\\.\n"
              raw.put_copy_data(row)
            end
          end
        elsif line.start_with?("SET ", "SELECT pg_catalog.setval(")
          connection.execute(line)
        end
      end
    end
  end
end
