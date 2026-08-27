class Customer < ApplicationRecord
  include Loggable

  has_many :integrateds, dependent: :destroy

  validates :name, presence: true

  private

  def activity_description
    "Cliente #{name}"
  end
end
