# db/seeds.rb

puts "🌱 Iniciando seeds..."

TENANT_NAME  = "fishtrack"
COMPANY_NAME = "Fish Track Aquicultura"
ADMIN_EMAIL  = "admin@fishtrack.com"
ADMIN_PASS   = "password123"

# ----------------------------
# Helpers
# ----------------------------
def rand_date_between(from:, to:)
  Time.at(rand(from.to_time.to_i..to.to_time.to_i)).to_date
end

def schema_exists?(schema_name)
  ActiveRecord::Base.connection.select_value(<<~SQL)
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = #{ActiveRecord::Base.connection.quote(schema_name)}
  SQL
end

def create_schema!(schema_name)
  ActiveRecord::Base.connection.execute(%{CREATE SCHEMA IF NOT EXISTS "#{schema_name}"})
end

def migrate_current_schema!
  ActiveRecord::MigrationContext.new(
    Rails.root.join("db/migrate").to_s,
    ActiveRecord::SchemaMigration
  ).migrate
end

def safe_delete_all!(model)
  return unless model.respond_to?(:connection) && model.respond_to?(:table_name)
  return unless model.connection.data_source_exists?(model.table_name)
  model.delete_all
end

# ----------------------------
# 1) PUBLIC: Company/User/Membership
# ----------------------------
public_company = nil
public_user    = nil

Apartment::Tenant.switch("public") do
  puts "🏢 [public] Garantindo Company..."
  public_company = Company.find_or_initialize_by(tenant_name: TENANT_NAME)
  public_company.name = COMPANY_NAME
  public_company.save!

  puts "👤 [public] Garantindo User admin..."
  public_user = User.find_or_initialize_by(email: ADMIN_EMAIL)
  public_user.name = "Admin" if public_user.respond_to?(:name=)
  public_user.password = ADMIN_PASS
  public_user.password_confirmation = ADMIN_PASS
  public_user.save!

  # Se ainda existir company_id no user, mantém compatibilidade
  if public_user.respond_to?(:company=)
    public_user.update!(company: public_company) rescue nil
  end

  if defined?(Membership)
    puts "🔗 [public] Garantindo Membership..."
    Membership.find_or_create_by!(user: public_user, company: public_company) do |m|
      m.role = "owner" if m.respond_to?(:role=)
    end
  else
    puts "⚠️ [public] Membership não existe (migration não aplicada ainda)."
  end

  # Garante que o schema do tenant existe de verdade no Postgres
  unless schema_exists?(TENANT_NAME)
    puts "🏗️ Schema '#{TENANT_NAME}' não existe no Postgres. Criando..."
    create_schema!(TENANT_NAME)
  else
    puts "🏗️ Schema '#{TENANT_NAME}' já existe no Postgres."
  end
end

# ----------------------------
# 2) TENANT: migra schema (cria tabelas do app no tenant)
# ----------------------------
puts "🧱 Migrando tenant '#{TENANT_NAME}'..."
Apartment::Tenant.switch(TENANT_NAME) do
  migrate_current_schema!
end

# ----------------------------
# 3) TENANT: seeds dos dados do app + Profile
# ----------------------------
Apartment::Tenant.switch(TENANT_NAME) do
  puts "🧩 [tenant=#{TENANT_NAME}] Preparando dados..."
  puts "🧼 [tenant=#{TENANT_NAME}] Limpando dados do tenant..."

  # Limpa apenas tabelas tenant-scoped (não apaga User/Company/Membership pois são do public)
  [
    (defined?(BatchEvent) ? BatchEvent : nil),
    (defined?(Batch) ? Batch : nil),
    (defined?(Pond) ? Pond : nil),
    (defined?(Unit) ? Unit : nil),
    (defined?(PayrollItem) ? PayrollItem : nil),
    (defined?(Employee) ? Employee : nil),
    (defined?(FinancialEntry) ? FinancialEntry : nil),
    (defined?(Profile) ? Profile : nil)
  ].compact.each do |model|
    safe_delete_all!(model)
  end

  # Recarrega user/company do public (garantido)
  admin_user = Apartment::Tenant.switch("public") { User.find_by!(email: ADMIN_EMAIL) }
  company    = Apartment::Tenant.switch("public") { Company.find_by!(tenant_name: TENANT_NAME) }

  puts "🪪 [tenant=#{TENANT_NAME}] Garantindo Profile do admin..."
  if defined?(Profile)
    Profile.find_or_create_by!(user_id: admin_user.id) do |p|
      p.display_name = admin_user.email if p.respond_to?(:display_name=)
    end
  else
    puts "⚠️ [tenant=#{TENANT_NAME}] Profile não existe (migration não aplicada ainda)."
  end

  puts "🏭 Criando unidades..."
  unit1 = Unit.new(name: "Fazenda Principal")
  unit2 = Unit.new(name: "Unidade Experimental")
  puts unit1.errors.full_messages unless unit1.valid?
  puts unit2.errors.full_messages unless unit2.valid?
  unit1.save!
  unit2.save!

  puts "💧 Criando açudes..."
  ponds = []
  ponds << Pond.create!(unit: unit1, name: "Açude 01", capacity: 15000, capacity_unit: "peixes")
  ponds << Pond.create!(unit: unit1, name: "Açude 02", capacity: 12000, capacity_unit: "peixes")
  ponds << Pond.create!(unit: unit1, name: "Açude 03", capacity: 18000, capacity_unit: "peixes")
  ponds << Pond.create!(unit: unit2, name: "Açude A",  capacity: 8000,  capacity_unit: "peixes")
  ponds << Pond.create!(unit: unit2, name: "Açude B",  capacity: 10000, capacity_unit: "peixes")

  puts "🐟 Criando lotes..."
  batches = []

  ponds.each_with_index do |pond, i|
    started_on = rand_date_between(from: 90.days.ago.to_date, to: 20.days.ago.to_date)

    batches << Batch.create!(
      pond: pond,
      name: "Lote #{pond.name}",
      species: "Tilápia",
      status: "active",
      stage: i.even? ? "juvenile" : "growout",
      started_on: started_on,
      initial_quantity: rand(6_000..14_000)
    )
  end

  closed_batch = Batch.create!(
    pond: ponds.first,
    name: "Lote Despesca (Fechado)",
    species: "Tilápia",
    status: "active", # vai virar closed após loading no recálculo
    stage: "growout",
    started_on: 140.days.ago.to_date,
    initial_quantity: 12_000
  )
  batches << closed_batch

  puts "📋 Criando eventos (biometria, mortalidade, ração, carregamento)..."
  batches.each do |batch|
    start = batch.started_on

    BatchEvent.create!(
      batch: batch,
      event_type: "biometrics",
      occurred_on: start + 7.days,
      avg_weight_g: rand(6.0..14.0).round(2),
      notes: "Biometria inicial"
    )

    3.times do |k|
      BatchEvent.create!(
        batch: batch,
        event_type: "mortality",
        occurred_on: start + (12 + k * 10).days,
        quantity: rand(15..90),
        notes: "Mortalidade no manejo"
      )
    end

    5.times do |k|
      BatchEvent.create!(
        batch: batch,
        event_type: "feeding",
        occurred_on: start + (10 + k * 6).days,
        feed_kg: rand(50.0..180.0).round(3),
        notes: "Arraçoamento"
      )
    end

    BatchEvent.create!(
      batch: batch,
      event_type: "biometrics",
      occurred_on: start + 35.days,
      avg_weight_g: rand(25.0..80.0).round(2),
      notes: "Biometria de acompanhamento"
    )
  end

  BatchEvent.create!(
    batch: closed_batch,
    event_type: "loading",
    occurred_on: Date.current - 15.days,
    notes: "Carregamento final (fechamento do lote)"
  )

  puts "🔁 Recalculando lotes (quantidade/peso/status)..."
  if Batch.instance_methods.include?(:recalculate_from_events!)
    Batch.find_each { |b| b.recalculate_from_events! }
  end

  puts "👷 Criando funcionários..."
  employees = []
  employees << Employee.new(name: "João da Silva", role: "Operador")
  employees << Employee.new(name: "Maria Souza", role: "Administrativo")
  employees << Employee.new(name: "Carlos Pereira", role: "Gerente")
  employees << Employee.new(name: "Ana Oliveira", role: "Técnica")
  employees.each do |e|
    e.save!
  end

  puts "🧾 Criando folha (salários + adiantamentos)..."
  today = Date.current
  year  = today.year
  month = today.month

  employees.each do |emp|
    salario = rand(4_000_00..7_500_00)

    item = PayrollItem.new(
      employee: emp,
      year: year,
      month: month,
      item_type: "salary",
      amount_cents: salario,
      occurred_on: Date.new(year, month, 5),
      notes: "Salário base #{month}/#{year}"
    )
    item.save!

    rand(0..2).times do |i|
      adv = PayrollItem.new(
        employee: emp,
        year: year,
        month: month,
        item_type: "advance",
        amount_cents: rand(500_00..1_500_00),
        occurred_on: Date.new(year, month, 10 + i * 5),
        notes: "Adiantamento #{i + 1}"
      )
      adv.save!
    end
  end

  puts "💸 Gerando lançamento financeiro da folha (líquido)..."
  items_scope = PayrollItem.where(year: year, month: month)
  items_scope = items_scope.where(company: company) if PayrollItem.reflect_on_association(:company)

  total = items_scope.sum do |i|
    case i.item_type
    when "salary", "bonus" then i.amount_cents
    when "advance", "discount" then -i.amount_cents
    else 0
    end
  end

  entry = FinancialEntry.new(
    entry_type: "expense",
    stage: "general",
    occurred_on: Date.new(year, month, 28),
    amount_cents: total,
    description: "Folha de pagamento #{month}/#{year}",
    notes: "Salários + adiantamentos (líquido)"
  )
  entry.save!

  puts "💰 Criando lançamentos financeiros (valores altos)..."
  [
    {
      entry_type: "expense",
      stage: "juvenile",
      occurred_on: Date.current.beginning_of_month,
      amount_cents: 520_000_00,
      description: "Compra de alevinos (juvenil)",
      notes: "Fornecedor X"
    },
    {
      entry_type: "expense",
      stage: "growout",
      occurred_on: Date.current.beginning_of_month + 2.days,
      amount_cents: 310_000_00,
      description: "Compra de ração (engorda)"
    },
    {
      entry_type: "expense",
      stage: "general",
      occurred_on: Date.current.beginning_of_month + 4.days,
      amount_cents: 75_000_00,
      description: "Manutenção geral / sede"
    },
    {
      entry_type: "income",
      stage: "growout",
      occurred_on: Date.current - 10.days,
      amount_cents: 1_250_000_00,
      description: "Venda de pescado (despesca)"
    }
  ].each do |attrs|
    fe = FinancialEntry.new(attrs)
    fe.save!
  end

  sample_batch = Batch.where(status: "active").first
  if sample_batch
    fe = FinancialEntry.new(
      unit: sample_batch.pond.unit,
      batch: sample_batch,
      entry_type: "expense",
      stage: sample_batch.stage,
      occurred_on: Date.current - 8.days,
      amount_cents: 28_000_00,
      description: "Medicamentos / insumos (lote)"
    )
    fe.save!
  end
end

puts "✅ Seed concluído!"
puts "🔑 Login: #{ADMIN_EMAIL} | #{ADMIN_PASS}"
puts "🏷️ Tenant: #{TENANT_NAME}"