class Customer < ApplicationRecord
  include Loggable

  has_many :integrateds, dependent: :destroy

  validates :name, presence: true

  # Endereço em uma linha para os impressos: "Rua A, 123 - Sala 2, Centro, Toledo/PR, CEP 85900-000".
  def full_address
    street = [address, address_number].compact_blank.join(", ")
    street = [street, address_complement].compact_blank.join(" - ")
    locality = [city, state].compact_blank.join("/")
    cep = "CEP #{postal_code}" if postal_code.present?

    [street, neighborhood, locality, cep].compact_blank.join(", ").presence
  end

  private

  def activity_description
    "Cliente #{name}"
  end
end
