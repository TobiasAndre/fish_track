require "zlib"

# Gera o backup do banco inteiro (schema público + o schema de cada empresa)
# num arquivo .sql.gz, usando só a conexão do próprio app: o servidor de
# produção não tem o pg_dump instalado.
#
# O arquivo traz os dados de todas as tabelas (blocos COPY, como os do pg_dump
# --data-only) e a posição das sequences. A estrutura das tabelas vem das
# migrations (db/schema.rb), então a restauração é feita pelo próprio app:
#
#   bin/rails db:create db:schema:load
#   bin/rails backup:restore FILE=fish_track-backup-....sql.gz
#
# As tabelas saem na ordem das chaves estrangeiras (a referenciada antes de
# quem a referencia), para a restauração não violar nenhuma FK.
class DatabaseBackup
  SKIPPED_TABLES = %w[schema_migrations ar_internal_metadata].freeze
  TITLE = "-- Fish Track: backup do banco de dados".freeze

  def initialize(connection: ActiveRecord::Base.connection)
    @connection = connection
  end

  def filename(at = Time.current)
    "fish_track-backup-#{at.strftime('%Y-%m-%d-%H%M%S')}.sql.gz"
  end

  # Grava o arquivo em `dir` e devolve o caminho.
  def create_file(dir)
    path = File.join(dir, filename)
    Zlib::GzipWriter.open(path) { |gz| write(gz) }
    path
  end

  def write(io)
    schemas = backup_schemas

    io.write(header(schemas))

    schemas.each do |schema|
      io.write("\n-- schema: #{schema}\n")
      tables_in_dependency_order(schema).each { |table| copy_table(io, schema, table) }
      sequences(schema).each { |row| io.write(setval_statement(schema, row)) }
    end

    io.write("\n-- fim do backup\n")
  end

  private

  attr_reader :connection

  # O público primeiro: é onde ficam usuários e empresas.
  def backup_schemas
    existing = connection.select_values("SELECT nspname FROM pg_namespace")
    tenants = connection.select_values("SELECT tenant_name FROM public.companies ORDER BY tenant_name")

    ["public", *tenants.select { |name| existing.include?(name) }.uniq]
  end

  def header(schemas)
    <<~SQL
      #{TITLE}
      -- gerado_em: #{Time.current.iso8601}
      -- versao_schema: #{connection.select_value("SELECT MAX(version) FROM public.schema_migrations")}
      -- schemas: #{schemas.join(",")}
      -- Para restaurar: bin/rails db:create db:schema:load && bin/rails backup:restore FILE=<este arquivo>
      SET client_encoding = 'UTF8';
      SET standard_conforming_strings = on;
    SQL
  end

  def tables_in_dependency_order(schema)
    tables = connection.select_values(sanitize(<<~SQL, schema)) - SKIPPED_TABLES
      SELECT tablename FROM pg_tables WHERE schemaname = ? ORDER BY tablename
    SQL

    parents = Hash.new { |hash, key| hash[key] = [] }
    connection.select_rows(sanitize(<<~SQL, schema, schema)).each { |child, parent| parents[child] << parent unless child == parent }
      SELECT child.relname, parent.relname
      FROM pg_constraint fk
      JOIN pg_class child ON child.oid = fk.conrelid
      JOIN pg_namespace child_ns ON child_ns.oid = child.relnamespace
      JOIN pg_class parent ON parent.oid = fk.confrelid
      JOIN pg_namespace parent_ns ON parent_ns.oid = parent.relnamespace
      WHERE fk.contype = 'f' AND child_ns.nspname = ? AND parent_ns.nspname = ?
    SQL

    ordered = []
    pending = tables.dup
    until pending.empty?
      ready = pending.select { |table| (parents[table] & pending).empty? }
      ready = [pending.first] if ready.empty? # ciclo de FKs: segue na ordem alfabética
      ordered.concat(ready)
      pending -= ready
    end
    ordered
  end

  def copy_table(io, schema, table)
    qualified = qualified_name(schema, table)
    columns = connection.select_values(sanitize(<<~SQL, qualified)).map { |column| quote_ident(column) }.join(", ")
      SELECT attname FROM pg_attribute
      WHERE attrelid = ?::regclass AND attnum > 0 AND NOT attisdropped AND attgenerated = ''
      ORDER BY attnum
    SQL

    io.write("\nCOPY #{qualified} (#{columns}) FROM stdin;\n")

    raw = connection.raw_connection
    raw.copy_data("COPY #{qualified} (#{columns}) TO STDOUT") do
      while (row = raw.get_copy_data)
        io.write(row)
      end
    end

    io.write("\\.\n")
  end

  def sequences(schema)
    connection.select_rows(sanitize(<<~SQL, schema))
      SELECT sequencename, last_value FROM pg_sequences WHERE schemaname = ? ORDER BY sequencename
    SQL
  end

  def setval_statement(schema, (sequence, last_value))
    called = !last_value.nil?
    "SELECT pg_catalog.setval(#{connection.quote(qualified_name(schema, sequence))}, #{(last_value || 1).to_i}, #{called});\n"
  end

  def qualified_name(schema, name)
    "#{quote_ident(schema)}.#{quote_ident(name)}"
  end

  def quote_ident(name)
    PG::Connection.quote_ident(name.to_s)
  end

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([sql, *binds])
  end
end
