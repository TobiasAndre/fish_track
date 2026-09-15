require "apartment/migrator"

module Admin
  class CreateCompanyWithTenant
    def initialize(company_params:, owner_user_id:)
      @company_params = company_params
      @owner_user_id = owner_user_id
    end

    def call
      company = Company.create!(@company_params)

      begin
        Apartment::Tenant.create(company.tenant_name)

        Apartment::Migrator.migrate(company.tenant_name)

        Membership.create!(
          user_id: owner_user_id,
          company: company,
          role: "owner"
        )

        company
      rescue StandardError => e
        Company.where(id: company.id).delete_all
        raise e
      end
    end

    private

    attr_reader :company_params, :owner_user_id
  end
end
