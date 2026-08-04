require "rails_helper"

RSpec.describe Simulation, type: :model do
  it "is valid with a customer, simulated_on, quantity, avg_weight_kg and pricing fields" do
    expect(build(:simulation)).to be_valid
  end

  it "is invalid without a customer" do
    simulation = build(:simulation, customer: nil)

    expect(simulation).not_to be_valid
    expect(simulation.errors[:customer]).to be_present
  end

  it "is invalid with a zero quantity" do
    simulation = build(:simulation, quantity: 0)

    expect(simulation).not_to be_valid
    expect(simulation.errors[:quantity]).to be_present
  end

  it "is invalid with a zero avg_weight_kg" do
    simulation = build(:simulation, avg_weight_kg: 0)

    expect(simulation).not_to be_valid
    expect(simulation.errors[:avg_weight_kg]).to be_present
  end

  describe "#normalize_numeric_fields" do
    it "strips non-digit characters from quantity and loading_count" do
      simulation = build(:simulation, quantity: "1.000", loading_count: "2")

      simulation.valid?

      expect(simulation.quantity).to eq(1000)
      expect(simulation.loading_count).to eq(2)
    end

    it "parses pt-BR formatted decimals for avg_weight_kg" do
      simulation = build(:simulation, avg_weight_kg: "1,5")

      simulation.valid?

      expect(simulation.avg_weight_kg).to eq(1.5)
    end
  end

  describe "#calculate_totals" do
    it "derives total_weight_kg from quantity and avg_weight_kg" do
      simulation = build(:simulation, quantity: 1000, avg_weight_kg: 0.5)

      simulation.valid?

      expect(simulation.total_weight_kg.to_f).to eq(500.0)
    end

    it "derives total_cents from the fish value plus loading and freight costs" do
      simulation = build(:simulation,
        quantity: 1000,
        avg_weight_kg: 0.5,
        price_per_kg_cents: 1_500,
        thousand_value_cents: 0,
        loading_cost_cents: 10_000,
        freight_cost_cents: 5_000)

      simulation.valid?

      # fish_total_cents = (0.5 * 1500 * 1000 + 0) * (1000 / 1000) = 750_000
      expect(simulation.total_cents).to eq(750_000 + 10_000 + 5_000)
    end
  end
end
