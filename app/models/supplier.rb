class Supplier < ApplicationRecord
  include Loggable

  validates :name, presence: true

  private

  def activity_description
    "Fornecedor #{name}"
  end
end
