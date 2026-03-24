class Customer < ApplicationRecord
  has_many :integrateds, dependent: :destroy

  validates :name, presence: true
end
