class Silo < ApplicationRecord
  belongs_to :unit

  has_many :stock_entries, class_name: "SiloStockEntry", dependent: :restrict_with_error

  before_validation :normalize_name

  validates :name, presence: true
  validate :name_must_be_unique_ignoring_case_and_spaces_within_unit

  private

  def normalize_name
    self.name = name.strip.squeeze(" ") if name.present?
  end

  def name_must_be_unique_ignoring_case_and_spaces_within_unit
    return if name.blank? || unit_id.blank?

    scope = self.class.where(unit_id: unit_id).where("lower(btrim(name)) = ?", name.downcase)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:name, "já está cadastrado para esta unidade") if scope.exists?
  end
end
