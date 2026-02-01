class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :company_id }

  ROLES = %w[owner admin member].freeze
  validates :role, inclusion: { in: ROLES }
end
