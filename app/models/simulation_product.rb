class SimulationProduct < ApplicationRecord
  belongs_to :simulation
  belongs_to :product

  validates :product_id, uniqueness: { scope: :simulation_id }
end
