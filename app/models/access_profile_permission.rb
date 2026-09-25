class AccessProfilePermission < ApplicationRecord
  belongs_to :access_profile, inverse_of: :permissions

  validates :resource, :action, presence: true
  validates :action, uniqueness: { scope: %i[access_profile_id resource] }
  validate :allowed_by_catalog

  private

  def allowed_by_catalog
    return if resource.blank? || action.blank?
    return if PermissionCatalog.valid?(resource, action)

    errors.add(:base, "Permissão inválida: #{resource} / #{action}")
  end
end
