TENANT_NAME="piscicultura_conte"
COMPANY_NAME = "Piscicultura Conte"
ADMIN_EMAIL  = "admin@fishtrack.com"
ADMIN_PASS   = "password123"

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
end
