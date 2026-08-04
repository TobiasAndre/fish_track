namespace :employees do
  desc "Backfill an initial salary_changes record for existing employees (idempotent, safe to re-run)"
  task backfill_salary_history: :environment do
    tenants = (["public"] + Apartment::Tenant.switch("public") { Company.pluck(:tenant_name) }).uniq

    tenants.each do |tenant|
      Apartment::Tenant.switch(tenant) do
        created = Employees::BackfillSalaryHistory.call
        puts "[#{tenant}] created #{created} initial salary_changes record(s)"
      end
    end
  end
end
