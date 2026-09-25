# O que o usuário logado pode fazer na empresa selecionada.
#
#   - administrador do sistema e donos/administradores da empresa: tudo;
#   - demais usuários: só o que o perfil de acesso atribuído a eles concede;
#   - sem perfil atribuído (ou com perfil que não existe mais): nada.
class AccessPolicy
  ADMIN_ROLES = %w[owner admin].freeze

  # Ações que não seguem o verbo HTTP: gerar o link de compartilhamento de um
  # relatório é uma leitura.
  ACTION_OVERRIDES = {
    %w[feeding_plans create_share] => "read",
    %w[batch_reports create_share] => "read",
    %w[loading_reports create_share] => "read",
    %w[silo_stock_reports create_share] => "read"
  }.freeze

  # Ação do catálogo (read/write/edit/delete) que um request exige.
  def self.required_action(controller_path, action_name, http_method)
    override = ACTION_OVERRIDES[[controller_path.to_s, action_name.to_s]]
    return override if override

    case action_name.to_s
    when "new", "create" then "write"
    when "edit", "update" then "edit"
    when "destroy" then "delete"
    else
      case http_method.to_s.upcase
      when "POST" then "write"
      when "PATCH", "PUT" then "edit"
      when "DELETE" then "delete"
      else "read"
      end
    end
  end

  # Rotas públicas por token (relatórios compartilhados) não passam pelo perfil.
  def self.public_action?(action_name)
    action_name.to_s.start_with?("share_")
  end

  def self.for(user:, company:)
    return new(full_access: true) if user&.system_admin?
    return new(full_access: false, permissions: Set.new) if user.nil? || company.nil?

    membership = Apartment::Tenant.switch("public") { Membership.find_by(user_id: user.id, company_id: company.id) }
    return new(full_access: false, permissions: Set.new) if membership.nil?
    return new(full_access: true) if ADMIN_ROLES.include?(membership.role)

    profile = membership.access_profile_id && AccessProfile.includes(:permissions).find_by(id: membership.access_profile_id)
    permissions = profile ? profile.permissions.map { |p| "#{p.resource}:#{p.action}" }.to_set : Set.new
    new(full_access: false, permissions: permissions, profile: profile)
  end

  attr_reader :profile

  def initialize(full_access:, permissions: Set.new, profile: nil)
    @full_access = full_access
    @permissions = permissions
    @profile = profile
  end

  def full_access?
    @full_access
  end

  def can?(resource_key, action)
    return PermissionCatalog.valid?(resource_key, action) if full_access?

    @permissions.include?("#{resource_key}:#{action}")
  end

  # Primeira página (na ordem do menu) que o usuário pode ver, fora `excluding`.
  def first_readable_resource(excluding: nil)
    PermissionCatalog.resources.find { |resource| resource != excluding && can?(resource.key, "read") }
  end
end
