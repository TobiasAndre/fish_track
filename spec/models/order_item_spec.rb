require "rails_helper"

RSpec.describe OrderItem, type: :model do
  it "is valid with an order, a product, quantity and unit_price_cents" do
    expect(build(:order_item)).to be_valid
  end

  it "is invalid with a zero quantity" do
    item = build(:order_item, quantity: 0)

    expect(item).not_to be_valid
    expect(item.errors[:quantity]).to be_present
  end

  it "is invalid with a negative unit_price_cents" do
    item = build(:order_item, unit_price_cents: -1)

    expect(item).not_to be_valid
    expect(item.errors[:unit_price_cents]).to be_present
  end

  describe "#calculate_total_cents" do
    it "multiplies quantity by unit_price_cents before validation" do
      item = build(:order_item, quantity: 2.5, unit_price_cents: 1_000)

      item.valid?

      expect(item.total_cents).to eq(2_500)
    end
  end
end
