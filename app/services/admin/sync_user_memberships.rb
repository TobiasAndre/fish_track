module Admin
  # Aplica o que veio do formulário de usuário: em quais empresas ele tem acesso,
  # com qual tipo (owner/admin/member) e, para membros, com qual perfil de acesso.
  #
  #   { "<company_id>" => { "enabled" => "1", "role" => "member", "access_profile_id" => "3" } }
  #
  # Só toca nas empresas presentes no formulário; o perfil só vale para membros
  # (donos e administradores já enxergam tudo) e precisa existir na empresa.
  class SyncUserMemberships
    def initialize(user:, params:)
      @user = user
      @params = params || {}
    end

    def call
      Company.order(:name).each do |company|
        entry = @params[company.id.to_s]
        next if entry.nil?

        if entry[:enabled].to_s == "1"
          save_membership(company, entry)
        else
          Membership.where(user_id: @user.id, company_id: company.id).destroy_all
        end
      end
    end

    private

    def save_membership(company, entry)
      role = Membership::ROLES.include?(entry[:role]) ? entry[:role] : "member"
      membership = Membership.find_or_initialize_by(user_id: @user.id, company_id: company.id)
      membership.role = role
      membership.access_profile_id = role == "member" ? valid_profile_id(company, entry[:access_profile_id]) : nil
      membership.save!
    end

    def valid_profile_id(company, raw_id)
      return nil if raw_id.blank?

      Apartment::Tenant.switch(company.tenant_name) { AccessProfile.find_by(id: raw_id)&.id }
    end
  end
end
