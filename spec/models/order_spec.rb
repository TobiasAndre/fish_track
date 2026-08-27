require "rails_helper"

RSpec.describe Order, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:order) }
  end

  it "is valid with a customer, a status and an occurred_on" do
    expect(build(:order)).to be_valid
  end

  it "is invalid without a customer" do
    order = build(:order, customer: nil)

    expect(order).not_to be_valid
    expect(order.errors[:customer]).to be_present
  end

  it "is invalid with a status outside the allowed list" do
    order = build(:order, status: "shipped")

    expect(order).not_to be_valid
    expect(order.errors[:status]).to be_present
  end

  describe "#recalculate_total_cents!" do
    it "sums the total_cents of its order items once they are persisted, on create" do
      product = create(:product)
      order = build(:order)
      order.order_items.build(product: product, quantity: 2, unit_price_cents: 1_000)
      order.order_items.build(product: product, quantity: 1, unit_price_cents: 500)

      order.save!

      expect(order.reload.total_cents).to eq(2_500)
    end

    it "recomputes the total after a nested order item quantity changes" do
      order = create(:order)
      item = create(:order_item, order: order, quantity: 1, unit_price_cents: 1_000)
      order.reload

      order.update!(order_items_attributes: [{ id: item.id, quantity: 5 }])

      expect(order.reload.total_cents).to eq(5_000)
    end

    it "excludes order items removed via nested attributes" do
      order = create(:order)
      kept = create(:order_item, order: order, quantity: 1, unit_price_cents: 1_000)
      to_remove = create(:order_item, order: order, quantity: 1, unit_price_cents: 500)
      order.reload

      order.update!(order_items_attributes: [{ id: to_remove.id, _destroy: true }])

      expect(order.reload.total_cents).to eq(kept.total_cents)
    end
  end

  describe "status predicates" do
    it "#cancelable? is false once delivered" do
      order = build(:order, status: "delivered")

      expect(order.cancelable?).to be false
    end

    it "#cancelable? is false once canceled" do
      order = build(:order, status: "canceled")

      expect(order.cancelable?).to be false
    end

    it "#cancelable? is true otherwise" do
      order = build(:order, status: "confirmed")

      expect(order.cancelable?).to be true
    end
  end
end
