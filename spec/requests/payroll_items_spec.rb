require "rails_helper"

RSpec.describe "PayrollItems", type: :request do
  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  describe "POST /payroll_items" do
    it "creates an advance and its linked financial entry" do
      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 50_000,
            item_type: "advance"
          }
        }
      end.to change(PayrollItem, :count).by(1).and change(FinancialEntry, :count).by(1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
    end

    it "creates a bonus without a standalone financial entry" do
      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 20_000,
            item_type: "bonus"
          }
        }
      end.to change(PayrollItem, :count).by(1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(PayrollItem.last.item_type).to eq("bonus")
      expect(FinancialEntry.count).to eq(0)
    end

    it "creates a discount without a standalone financial entry" do
      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 15_000,
            item_type: "discount"
          }
        }
      end.to change(PayrollItem, :count).by(1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(PayrollItem.last.item_type).to eq("discount")
      expect(FinancialEntry.count).to eq(0)
    end

    it "creates a salary payment and its linked financial entry" do
      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 300_000,
            item_type: "salary_payment"
          }
        }
      end.to change(PayrollItem, :count).by(1).and change(FinancialEntry, :count).by(1)

      expect(FinancialEntry.last.description).to start_with("Pagamento salário")
    end

    it "refuses a second salary payment for the same competence" do
      create(
        :payroll_item, employee: employee, item_type: "salary_payment",
        year: 2026, month: 6, amount_cents: 300_000
      )

      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 300_000,
            item_type: "salary_payment"
          }
        }
      end.not_to change(PayrollItem, :count)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(flash[:alert]).to be_present
    end

    it "uses the given occurred_on instead of defaulting to the first of the month" do
      post payroll_items_path, params: {
        payroll_item: {
          employee_id: employee.id,
          year: 2026,
          month: 6,
          amount_cents: 50_000,
          item_type: "advance",
          occurred_on: "2026-06-15"
        }
      }

      expect(PayrollItem.last.occurred_on).to eq(Date.new(2026, 6, 15))
    end

    it "defaults occurred_on to the first of the competence month when left blank" do
      post payroll_items_path, params: {
        payroll_item: {
          employee_id: employee.id,
          year: 2026,
          month: 6,
          amount_cents: 50_000,
          item_type: "advance",
          occurred_on: ""
        }
      }

      expect(PayrollItem.last.occurred_on).to eq(Date.new(2026, 6, 1))
    end

    it "redirects back with an alert when the amount is invalid" do
      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id,
            year: 2026,
            month: 6,
            amount_cents: 0,
            item_type: "advance"
          }
        }
      end.not_to change(PayrollItem, :count)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /payroll_items/:id" do
    it "removes the payroll item" do
      item = create(:payroll_item, employee: employee, year: 2026, month: 6)

      expect do
        delete payroll_item_path(item)
      end.to change(PayrollItem, :count).by(-1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
    end
  end
end
