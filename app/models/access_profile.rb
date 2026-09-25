# Perfil de acesso: conjunto de permissões (página x ação) que será atribuído
# aos usuários da empresa. Vive no schema da empresa (tenant).
class AccessProfile < ApplicationRecord
  include Loggable

  has_many :permissions, class_name: "AccessProfilePermission", dependent: :destroy, inverse_of: :access_profile, autosave: true

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(Arel.sql("lower(access_profiles.name)")) }

  # { "units" => ["read", "edit"], ... } (só o que o perfil concede)
  def permission_map
    permissions.reject(&:marked_for_destruction?).group_by(&:resource).transform_values { |list| list.map(&:action) }
  end

  def granted?(resource, action)
    permissions.any? { |p| !p.marked_for_destruction? && p.resource == resource.to_s && p.action == action.to_s }
  end

  def permissions_count
    permissions.count { |p| !p.marked_for_destruction? }
  end

  # Recebe o que veio da tela ({ "units" => ["read", "write"] }), ignora o que o
  # catálogo não conhece e sincroniza as permissões (grava no save). Quem pode
  # criar, editar ou excluir precisa poder visualizar, então "read" é incluído.
  def permission_matrix=(matrix)
    desired = normalize(matrix)

    permissions.each do |permission|
      permission.mark_for_destruction unless desired.include?([permission.resource, permission.action])
    end

    existing = permissions.reject(&:marked_for_destruction?).map { |p| [p.resource, p.action] }
    (desired - existing).each { |resource, action| permissions.build(resource: resource, action: action) }
  end

  private

  def normalize(matrix)
    granted = Set.new

    (matrix || {}).each do |resource, actions|
      next unless actions.is_a?(Array)

      actions.map(&:to_s).each do |action|
        granted << [resource.to_s, action] if PermissionCatalog.valid?(resource, action)
      end
    end

    granted.map(&:first).uniq.each do |resource|
      granted << [resource, "read"] if granted.any? { |r, _| r == resource }
    end

    granted.to_a
  end

  def activity_description
    "Perfil de acesso #{name}"
  end
end
