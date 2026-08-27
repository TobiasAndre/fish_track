class Pond < ApplicationRecord
  include Loggable

  belongs_to :unit

  has_many :batch_stockings, dependent: :destroy
  has_many :batches, through: :batch_stockings

  def full_name
    [unit&.name, name].compact.join(" - ")
  end

  private

  def activity_description
    "Tanque #{full_name}"
  end
end
