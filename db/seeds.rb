TENANT_NAME = "piscicultura_conte"
COMPANY_NAME = "Piscicultura Conte"
ADMIN_EMAIL = "admin@fishtrack.com"
ADMIN_PASS = "password123"

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
end

existing_schemas =
  ActiveRecord::Base.connection.select_values(
    "SELECT schema_name FROM information_schema.schemata"
  )

unless existing_schemas.include?(TENANT_NAME)
  puts "🏗️ Criando schema/tenant #{TENANT_NAME}..."
  Apartment::Tenant.create(TENANT_NAME)
end

Apartment::Tenant.switch(TENANT_NAME) do
  puts "🐟 Garantindo tabela de arraçoamento..."

  temperature_ranges = [
    [15, 16],
    [17, 18],
    [19, 20],
    [21, 23],
    [24, 26],
    [27, 29],
    [30, 31]
  ]

  temperature_ranges.each do |from, to|
    FeedingTemperatureRange.find_or_create_by!(
      temperature_from: from,
      temperature_to: to
    )
  end

  puts "⚖️ Garantindo faixas de peso..."

  weight_ranges = [
    [0.3, 2.9],
    [3, 9.9],
    [10, 13.9],
    [14, 19.9],
    [20, 39.9],
    [40, 57.9],
    [58, 73.9],
    [74, 94.9],
    [95, 115.9],
    [116, 136.9],
    [137, 180.9],
    [181, 219.9],
    [220, 238.9],
    [239, 283.9],
    [284, 299.9],
    [300, 385.9],
    [386, 489.9],
    [490, 652.9],
    [653, 721.9],
    [722, 812.9],
    [813, 1200]
  ]

  weight_ranges.each do |from, to|
    FeedingWeightRange.find_or_create_by!(
      weight_from: from,
      weight_to: to
    )
  end
end

puts "✅ Seeds finalizados com sucesso."