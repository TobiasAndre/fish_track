class Integrated < ApplicationRecord
  include Loggable

  belongs_to :customer
  has_many :simulations

  validates :name, presence: true

  private

  def activity_description
    "Integrado #{name} (#{customer&.name})"
  end
end
