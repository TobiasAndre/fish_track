# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
puts "🌱 Limpando base..."

[
  BatchEvent,
  Batch,
  Pond,
  Unit,
  PayrollItem,
  Employee,
  FinancialEntry,
  Company,
  User
].each do |model|
  model.delete_all if model.table_exists?
end

# Helpers
def rand_date_between(from:, to:)
  Time.at(rand(from.to_time.to_i..to.to_time.to_i)).to_date
end

puts "👤 Criando usuário..."
user = User.create!(
  email: "admin@fishtrack.com",
  name: "Admin",
  password: "password123",
  password_confirmation: "password123"
)

puts "🏢 Criando empresa..."
company = Company.create!(
  name: "Fish Track Aquicultura"
)

# Se seu User já tem company_id (pelo schema tem), linka:
user.update!(company: company)

puts "🏭 Criando unidades..."
unit1 = company.units.create!(name: "Fazenda Principal")
unit2 = company.units.create!(name: "Unidade Experimental")

puts "💧 Criando açudes..."
ponds = []
ponds << unit1.ponds.create!(name: "Açude 01", capacity: 15000, capacity_unit: "peixes")
ponds << unit1.ponds.create!(name: "Açude 02", capacity: 12000, capacity_unit: "peixes")
ponds << unit1.ponds.create!(name: "Açude 03", capacity: 18000, capacity_unit: "peixes")
ponds << unit2.ponds.create!(name: "Açude A", capacity: 8000,  capacity_unit: "peixes")
ponds << unit2.ponds.create!(name: "Açude B", capacity: 10000, capacity_unit: "peixes")

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

# Um lote fechado (carregamento = fechamento)
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

  # biometria 1
  BatchEvent.create!(
    batch: batch,
    event_type: "biometrics",
    occurred_on: start + 7.days,
    avg_weight_g: rand(6.0..14.0).round(2),
    notes: "Biometria inicial"
  )

  # mortalidade (algumas)
  3.times do |k|
    BatchEvent.create!(
      batch: batch,
      event_type: "mortality",
      occurred_on: start + (12 + k * 10).days,
      quantity: rand(15..90),
      notes: "Mortalidade no manejo"
    )
  end

  # ração (lançamentos)
  5.times do |k|
    BatchEvent.create!(
      batch: batch,
      event_type: "feeding",
      occurred_on: start + (10 + k * 6).days,
      feed_kg: rand(50.0..180.0).round(3),
      notes: "Arraçoamento"
    )
  end

  # biometria 2
  BatchEvent.create!(
    batch: batch,
    event_type: "biometrics",
    occurred_on: start + 35.days,
    avg_weight_g: rand(25.0..80.0).round(2),
    notes: "Biometria de acompanhamento"
  )
end

# Fecha o lote especial com loading (carregamento)
BatchEvent.create!(
  batch: closed_batch,
  event_type: "loading",
  occurred_on: Date.current - 15.days,
  notes: "Carregamento final (fechamento do lote)"
)

puts "🔁 Recalculando lotes (quantidade/peso/status)..."
Batch.find_each do |b|
  b.recalculate_from_events! if b.respond_to?(:recalculate_from_events!)
end

puts "👷 Criando funcionários..."
employees = []
employees << company.employees.create!(name: "João da Silva", role: "Operador")
employees << company.employees.create!(name: "Maria Souza", role: "Administrativo")
employees << company.employees.create!(name: "Carlos Pereira", role: "Gerente")
employees << company.employees.create!(name: "Ana Oliveira", role: "Técnica")

puts "🧾 Criando folha (salários + adiantamentos)..."

today = Date.current
year  = today.year
month = today.month

employees.each do |emp|
  salario = rand(4_000_00..7_500_00)

  PayrollItem.create!(
    company: company,
    employee: emp,
    year: year,
    month: month,
    item_type: "salary",
    amount_cents: salario,
    occurred_on: Date.new(year, month, 5),
    notes: "Salário base #{month}/#{year}"
  )

  # adiantamentos (0 a 2)
  rand(0..2).times do |i|
    PayrollItem.create!(
      company: company,
      employee: emp,
      year: year,
      month: month,
      item_type: "advance",
      amount_cents: rand(500_00..1_500_00),
      occurred_on: Date.new(year, month, 10 + i * 5),
      notes: "Adiantamento #{i + 1}"
    )
  end
end

puts "💸 Gerando lançamento financeiro da folha (líquido)..."

items = PayrollItem.where(company: company, year: year, month: month)

total = items.sum do |i|
  case i.item_type
  when "salary", "bonus"
    i.amount_cents
  when "advance", "discount"
    -i.amount_cents
  else
    0
  end
end

FinancialEntry.create!(
  company: company,
  entry_type: "expense",
  stage: "general",
  occurred_on: Date.new(year, month, 28),
  amount_cents: total,
  description: "Folha de pagamento #{month}/#{year}",
  notes: "Salários + adiantamentos (líquido)"
)

puts "💰 Criando lançamentos financeiros (valores altos)..."
FinancialEntry.create!(
  company: company,
  entry_type: "expense",
  stage: "juvenile",
  occurred_on: Date.current.beginning_of_month,
  amount_cents: 520_000_00, # R$ 520.000,00
  description: "Compra de alevinos (juvenil)",
  notes: "Fornecedor X"
)

FinancialEntry.create!(
  company: company,
  entry_type: "expense",
  stage: "growout",
  occurred_on: Date.current.beginning_of_month + 2.days,
  amount_cents: 310_000_00, # R$ 310.000,00
  description: "Compra de ração (engorda)"
)

FinancialEntry.create!(
  company: company,
  entry_type: "expense",
  stage: "general",
  occurred_on: Date.current.beginning_of_month + 4.days,
  amount_cents: 75_000_00, # R$ 75.000,00
  description: "Manutenção geral / sede"
)

FinancialEntry.create!(
  company: company,
  entry_type: "income",
  stage: "growout",
  occurred_on: Date.current - 10.days,
  amount_cents: 1_250_000_00, # R$ 1.250.000,00
  description: "Venda de pescado (despesca)"
)

# Alguns lançamentos vinculados a lote e unidade (para demonstrar filtros)
sample_batch = company.batches.where(status: "active").first
FinancialEntry.create!(
  company: company,
  unit: sample_batch.pond.unit,
  batch: sample_batch,
  entry_type: "expense",
  stage: sample_batch.stage,
  occurred_on: Date.current - 8.days,
  amount_cents: 28_000_00,
  description: "Medicamentos / insumos (lote)"
)

puts "✅ Seed concluído!"
puts "🔑 Login: admin@fishtrack.com | password123"
