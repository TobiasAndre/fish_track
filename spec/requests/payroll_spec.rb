require "rails_helper"

RSpec.describe "Payroll", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  describe "GET /payroll" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get payroll_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the payroll for the given month" do
      create(:payroll_item, employee: employee, item_type: "salary", year: 2026, month: 6, amount_cents: 500_000)

      get payroll_path, params: { year: 2026, month: 6 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.name)
    end
  end

  describe "GET /payroll uses the salary vigente na competência" do
    it "shows the salary that was in effect during an old competence, not the current one" do
      employee = create(:employee, name: "Histórico Salarial", salary_cents: 300_000, started_on: Date.new(2024, 1, 1))
      Employees::RegisterSalaryChange.new(
        employee: employee, salary_cents: 400_000, effective_on: Date.new(2026, 1, 1), change_type: "adjustment"
      ).call

      get payroll_path, params: { year: 2025, month: 6 } # a competence before the raise

      expect(response.body).to include("R$  3.000,00")
      expect(response.body).not_to include("R$  4.000,00")
    end

    it "does not let the current salary retroactively change an old payroll" do
      employee = create(:employee, name: "Sem Retroatividade", salary_cents: 300_000, started_on: Date.new(2024, 1, 1))

      get payroll_path, params: { year: 2024, month: 6 }
      expect(response.body).to include("R$  3.000,00")

      Employees::RegisterSalaryChange.new(
        employee: employee, salary_cents: 500_000, effective_on: Date.current, change_type: "adjustment"
      ).call

      get payroll_path, params: { year: 2024, month: 6 }
      expect(response.body).to include("R$  3.000,00")
      expect(response.body).not_to include("R$  5.000,00")
    end

    it "shows the current salary for the present competence" do
      employee = create(:employee, name: "Competência Atual", salary_cents: 300_000, started_on: 2.years.ago.to_date)

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  3.000,00")
    end
  end

  describe "GET /payroll alerts" do
    it "shows the alert details in a tooltip and links to the employee page" do
      employee = create(:employee, name: "Com Alerta", started_on: Date.new(2020, 3, 15))
      create(:employee_vacation, employee: employee, status: "available")

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("alerta(s)")
      expect(response.body).to include(employee_path(employee))
      expect(response.body).to include("Férias disponíveis")
    end
  end

  describe "GET /payroll with bonuses" do
    it "adds bonus amounts on top of the salary in the balance to pay" do
      employee = create(:employee, name: "Com Bônus", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "bonus",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  3.500,00")
    end

    it "subtracts advances after adding bonuses" do
      employee = create(:employee, name: "Bônus E Adiantamento", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "bonus",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )
      create(
        :payroll_item, employee: employee, item_type: "advance",
        year: Date.current.year, month: Date.current.month, amount_cents: 100_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  2.500,00")
    end
  end

  describe "GET /payroll with discounts" do
    it "subtracts discount amounts from the balance to pay" do
      employee = create(:employee, name: "Com Desconto", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "discount",
        year: Date.current.year, month: Date.current.month, amount_cents: 50_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("R$  2.500,00")
    end
  end

  describe "GET /payroll salary payment" do
    it "offers a button to mark the salary as paid when there is a balance" do
      create(:employee, name: "A Pagar", salary_cents: 300_000, started_on: 2.years.ago.to_date)

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("Marcar salário como pago")
    end

    it "shows the paid state and reduces the outstanding balance once paid" do
      employee = create(:employee, name: "Ja Pago", salary_cents: 300_000, started_on: 2.years.ago.to_date)
      create(
        :payroll_item, employee: employee, item_type: "salary_payment",
        year: Date.current.year, month: Date.current.month, amount_cents: 300_000
      )

      get payroll_path, params: { year: Date.current.year, month: Date.current.month }

      expect(response.body).to include("Estornar pagamento")
      expect(response.body).not_to include("Marcar salário como pago")
    end
  end

  describe "GET /payroll for a terminated employee" do
    it "shows the acerto rescisório card for the competência of the termination" do
      employee = create(
        :employee, name: "Desligado", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 8 }

      expect(response.body).to include("Acerto rescisório")
      expect(response.body).to include("Saldo de salário")
      expect(response.body).to include("13º salário proporcional")
      expect(response.body).to include(termination_report_employee_path(employee))
    end

    it "does not show the card on competências other than the termination month" do
      create(
        :employee, name: "Desligado Antes", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 9 }

      expect(response.body).not_to include("Acerto rescisório")
    end

    it "hides the employee entirely on competências after the termination month" do
      create(
        :employee, name: "Fulano Desligado", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 9 }

      expect(response.body).not_to include("Fulano Desligado")
    end

    it "still lists the employee on competências before the termination" do
      create(
        :employee, name: "Fulano Ativo Antes", salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      get payroll_path, params: { year: 2026, month: 7 }

      expect(response.body).to include("Fulano Ativo Antes")
    end

    it "creates a payroll item when the lançar button is submitted" do
      employee = create(
        :employee, salary_cents: 300_000,
        started_on: Date.new(2024, 1, 10), status: "terminated", terminated_on: Date.new(2026, 8, 20)
      )

      expect do
        post payroll_items_path, params: {
          payroll_item: {
            employee_id: employee.id, year: 2026, month: 8, item_type: "bonus",
            occurred_on: employee.terminated_on, amount_cents: 200_000,
            notes: "13º salário proporcional (acerto rescisório)"
          }
        }
      end.to change(PayrollItem, :count).by(1)

      item = PayrollItem.last
      expect(item.item_type).to eq("bonus")
      expect(item.amount_cents).to eq(200_000)
    end
  end

  describe "PATCH /payroll" do
    it "creates a salary payroll item for each employee with a positive amount" do
      expect do
        patch payroll_path, params: {
          year: 2026,
          month: 6,
          salaries: { employee.id.to_s => "500000" }
        }
      end.to change { PayrollItem.where(employee: employee, item_type: "salary", year: 2026, month: 6).count }.by(1)

      expect(response).to redirect_to(payroll_path(year: 2026, month: 6))
      expect(PayrollItem.find_by(employee: employee, item_type: "salary", year: 2026, month: 6).amount_cents).to eq(500_000)
    end

    it "removes the salary item when the amount is zeroed out" do
      create(:payroll_item, employee: employee, item_type: "salary", year: 2026, month: 6, amount_cents: 500_000)

      expect do
        patch payroll_path, params: {
          year: 2026,
          month: 6,
          salaries: { employee.id.to_s => "0" }
        }
      end.to change { PayrollItem.where(employee: employee, item_type: "salary", year: 2026, month: 6).count }.by(-1)
    end
  end

  describe "Turbo Frames (only the employee's card reloads)" do
    let(:year) { Date.current.year }
    let(:month) { Date.current.month }
    let!(:joao) { create(:employee, name: "João Frame", salary_cents: 300_000, started_on: 2.years.ago.to_date) }
    let!(:maria) { create(:employee, name: "Maria Frame", salary_cents: 400_000, started_on: 2.years.ago.to_date) }

    def doc
      Nokogiri::HTML(response.body)
    end

    def frame_headers(employee)
      { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(employee, :payroll) }
    end

    it "puts each employee's card in its own frame" do
      get payroll_path, params: { year: year, month: month }

      ids = doc.css("turbo-frame").map { |f| f["id"] }
      expect(ids).to contain_exactly("payroll_employee_#{joao.id}", "payroll_employee_#{maria.id}")
      expect(doc.at_css("turbo-frame#payroll_employee_#{joao.id}").text).to include("João Frame", "Novo lançamento")
      expect(doc.at_css("h1")&.ancestors("turbo-frame").to_a).to be_empty
    end

    it "renders only the requested employee on a frame request (no layout, no other cards)" do
      get payroll_path, params: { year: year, month: month }, headers: frame_headers(joao)

      expect(doc.css("turbo-frame").map { |f| f["id"] }).to eq(["payroll_employee_#{joao.id}"])
      expect(response.body).to include("João Frame")
      expect(response.body).not_to include("Maria Frame")
      expect(doc.css("nav")).to be_empty
    end

    it "renders every employee, and no frame-level toast, on a normal request" do
      get payroll_path, params: { year: year, month: month }

      expect(response.body).to include("João Frame", "Maria Frame")
      expect(doc.css("turbo-frame [data-controller=flash]")).to be_empty
    end

    it "shows the flash toast inside the frame after an action, once" do
      post payroll_items_path, params: {
        payroll_item: { employee_id: joao.id, year: year, month: month, amount_cents: 20_000, item_type: "advance" }
      }, headers: frame_headers(joao)
      follow_redirect!(headers: frame_headers(joao))

      toasts = doc.css("turbo-frame#payroll_employee_#{joao.id} [data-controller=flash]")
      expect(toasts.size).to eq(1)
      expect(toasts.sole["data-flash-message-value"]).to eq("Adiantamento lançado!")
      expect(doc.css("[data-controller=flash]").size).to eq(1)
    end

    it "updates the card's numbers after a launch (advance reduces the balance to pay)" do
      post payroll_items_path, params: {
        payroll_item: { employee_id: joao.id, year: year, month: month, amount_cents: 100_000, item_type: "advance" }
      }, headers: frame_headers(joao)
      follow_redirect!(headers: frame_headers(joao))

      card = doc.at_css("turbo-frame#payroll_employee_#{joao.id}")
      expect(card.text.gsub(/\s+/, " ")).to include("Saldo a pagar R$ 2.000,00")
    end

    it "shows the error toast inside the frame when the launch is refused" do
      create(:payroll_item, employee: joao, item_type: "salary_payment", year: year, month: month, amount_cents: 300_000)

      post payroll_items_path, params: {
        payroll_item: { employee_id: joao.id, year: year, month: month, amount_cents: 300_000, item_type: "salary_payment" }
      }, headers: frame_headers(joao)
      follow_redirect!(headers: frame_headers(joao))

      toast = doc.css("turbo-frame#payroll_employee_#{joao.id} [data-controller=flash]").sole
      expect(toast["data-flash-type-value"]).to eq("error")
      expect(toast["data-flash-message-value"]).to include("já foi marcado como pago")
    end

    it "removes a record and refreshes only that card" do
      item = create(:payroll_item, employee: joao, item_type: "bonus", year: year, month: month, amount_cents: 50_000)

      delete payroll_item_path(item), headers: frame_headers(joao)
      follow_redirect!(headers: frame_headers(joao))

      expect(PayrollItem.exists?(item.id)).to be(false)
      expect(doc.css("turbo-frame").map { |f| f["id"] }).to eq(["payroll_employee_#{joao.id}"])
      expect(doc.css("[data-controller=flash]").sole["data-flash-message-value"]).to eq("Registro removido!")
    end

    it "sends the links to the employee page out of the frame" do
      get payroll_path, params: { year: year, month: month }

      links = doc.css("turbo-frame#payroll_employee_#{joao.id} a[href='#{employee_path(joao)}']")
      expect(links).not_to be_empty
      expect(links.map { |a| a["data-turbo-frame"] }.uniq).to eq(["_top"])
    end

    it "ignores a frame id that doesn't match an employee card" do
      get payroll_path, params: { year: year, month: month }, headers: { "Turbo-Frame" => "something_else" }

      expect(response.body).to include("João Frame", "Maria Frame")
    end
  end
end
