require "rails_helper"

RSpec.describe SimulationProduct, type: :model do
  it "is valid with a simulation and a product" do
    expect(build(:simulation_product)).to be_valid
  end

  it "is invalid when the product is duplicated within the same simulation" do
    simulation = create(:simulation)
    product = create(:product)
    create(:simulation_product, simulation: simulation, product: product)

    duplicate = build(:simulation_product, simulation: simulation, product: product)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:product_id]).to be_present
  end
end
