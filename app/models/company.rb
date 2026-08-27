class Company < ApplicationRecord
  include Loggable

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :tenant_name,
            presence: true,
            uniqueness: true,
            format: { with: /\A[a-z0-9_]+\z/, message: "deve conter apenas letras minúsculas, números e underscore" }

  private

  def activity_description
    "Empresa #{name}"
  end
end
