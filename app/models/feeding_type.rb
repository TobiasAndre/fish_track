class FeedingType < ApplicationRecord
  belongs_to :feeding_brand

  has_many :stocking_events, dependent: :restrict_with_error
  has_many :silo_stock_entries, dependent: :restrict_with_error

  before_validation :normalize_name

  validates :name, presence: true
  validate :name_must_be_unique_ignoring_case_and_spaces_within_brand

  private

  def normalize_name
    self.name = name.strip.squeeze(" ") if name.present?
  end

  def name_must_be_unique_ignoring_case_and_spaces_within_brand
    return if name.blank? || feeding_brand_id.blank?

    scope = self.class.where(feeding_brand_id: feeding_brand_id)
      .where("lower(btrim(name)) = ?", name.downcase)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:name, "já está cadastrado para esta marca") if scope.exists?
  end
end
