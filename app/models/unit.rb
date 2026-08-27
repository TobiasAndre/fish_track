class Unit < ApplicationRecord
  include Loggable

  has_many :ponds, dependent: :destroy
  has_many :silos, dependent: :destroy

  validates :name, presence: true

  private

  def activity_description
    "Unidade #{name}"
  end
end
