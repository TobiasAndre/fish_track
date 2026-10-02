require "rails_helper"
require "tmpdir"

RSpec.describe DatabaseBackup do
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  def read(path)
    Zlib::GzipReader.open(path, &:read)
  end

  def wipe_public_tables
    tables = connection.select_values("SELECT tablename FROM pg_tables WHERE schemaname = 'public'") - described_class::SKIPPED_TABLES
    connection.execute("TRUNCATE #{tables.map { |table| "public.#{PG::Connection.quote_ident(table)}" }.join(', ')} CASCADE")
  end

  it "writes a gzipped file with a header, the data of every table and the sequences" do
    create(:customer, name: "Piscicultura Boa Vista")

    content = read(described_class.new.create_file(@dir))

    expect(content.lines.first.chomp).to eq(described_class::TITLE)
    expect(content).to include("-- schemas: public")
    expect(content).to include(%(COPY "public"."customers" ))
    expect(content).to include("Piscicultura Boa Vista")
    expect(content).to include(%q{SELECT pg_catalog.setval('"public"."customers_id_seq"'})
    expect(content).not_to include(%("public"."schema_migrations"))
  end

  it "puts a referenced table before the tables that reference it" do
    content = read(described_class.new.create_file(@dir))

    expect(content.index(%(COPY "public"."customers" ))).to be < content.index(%(COPY "public"."integrateds" ))
    expect(content.index(%(COPY "public"."users" ))).to be < content.index(%(COPY "public"."memberships" ))
  end

  it "is restored by DatabaseRestore with the same data, including tricky text and the sequence position" do
    customer = create(:customer, name: "Tab\there, \\barra\\ e\nquebra de linha; aspas 'simples' \"duplas\"", tax_id: "12345678901")
    integrated = create(:integrated, customer: customer, name: "Integrado Ação")
    path = described_class.new.create_file(@dir)
    next_id_before = connection.select_value("SELECT last_value FROM customers_id_seq")

    wipe_public_tables
    DatabaseRestore.new(path).call

    expect(Customer.find(customer.id)).to have_attributes(name: customer.name, tax_id: "12345678901")
    expect(Integrated.find(integrated.id)).to have_attributes(name: "Integrado Ação", customer_id: customer.id)
    expect(connection.select_value("SELECT last_value FROM customers_id_seq")).to eq(next_id_before)
  end

  describe DatabaseRestore do
    it "refuses to load over existing data" do
      create(:customer)
      path = DatabaseBackup.new.create_file(@dir)

      expect { described_class.new(path).call }.to raise_error(DatabaseRestore::Error, /já tem dados/)
    end

    it "refuses a file that is not a Fish Track backup" do
      path = File.join(@dir, "other.sql.gz")
      Zlib::GzipWriter.open(path) { |gz| gz.write("SELECT 1;\n") }

      expect { described_class.new(path).call }.to raise_error(DatabaseRestore::Error, /não é um backup/)
    end

    it "refuses a backup made by a newer version of the database" do
      path = File.join(@dir, "newer.sql.gz")
      Zlib::GzipWriter.open(path) do |gz|
        gz.write("#{DatabaseBackup::TITLE}\n-- versao_schema: 99990101000000\n-- schemas: public\n")
      end

      expect { described_class.new(path).call }.to raise_error(DatabaseRestore::Error, /Atualize o código/)
    end
  end
end
