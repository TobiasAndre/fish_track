require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:user) { create(:user) }
  let(:customer) { create(:customer) }
  let(:payment_method) { create(:payment_method) }
  let(:payment_term) { create(:payment_term) }
  let(:product) { create(:product) }

  before { sign_in user }

  describe "GET /orders" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get orders_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists orders" do
      order = create(:order, customer: customer, payment_method: payment_method, payment_term: payment_term)

      get orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.name)
      expect(order).to be_present
    end
  end

  describe "POST /orders" do
    it "creates an order with nested order items and computes the total" do
      expect do
        post orders_path, params: {
          order: {
            customer_id: customer.id,
            payment_method_id: payment_method.id,
            payment_term_id: payment_term.id,
            status: "draft",
            occurred_on: Date.current,
            order_items_attributes: {
              "0" => { product_id: product.id, quantity: 2, unit_price_cents: 1_000 }
            }
          }
        }
      end.to change(Order, :count).by(1)

      expect(response).to redirect_to(orders_path)
      expect(Order.last.total_cents).to eq(2_000)
    end

    it "does not create an order without a customer" do
      expect do
        post orders_path, params: {
          order: {
            customer_id: nil,
            payment_method_id: payment_method.id,
            payment_term_id: payment_term.id,
            status: "draft",
            occurred_on: Date.current
          }
        }
      end.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /orders/:id" do
    it "updates the order" do
      order = create(:order, customer: customer, payment_method: payment_method, payment_term: payment_term, notes: "old")

      patch order_path(order), params: { order: { notes: "new" } }

      expect(response).to redirect_to(orders_path)
      expect(order.reload.notes).to eq("new")
    end
  end

  describe "DELETE /orders/:id" do
    it "removes the order" do
      order = create(:order, customer: customer, payment_method: payment_method, payment_term: payment_term)

      expect do
        delete order_path(order)
      end.to change(Order, :count).by(-1)

      expect(response).to redirect_to(orders_path)
    end
  end

  describe "PATCH /orders/:id/cancel" do
    it "cancels a cancelable order" do
      order = create(:order, customer: customer, payment_method: payment_method, payment_term: payment_term, status: "confirmed")

      patch cancel_order_path(order)

      expect(response).to redirect_to(orders_path)
      expect(order.reload.status).to eq("canceled")
    end

    it "refuses to cancel a delivered order" do
      order = create(:order, customer: customer, payment_method: payment_method, payment_term: payment_term, status: "delivered")

      patch cancel_order_path(order)

      expect(response).to redirect_to(orders_path)
      expect(order.reload.status).to eq("delivered")
    end
  end
end
