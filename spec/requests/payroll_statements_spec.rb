require "rails_helper"

RSpec.describe "PayrollStatements", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:employee) { create(:employee, name: "Carlos Tratador", role: "Tratador", salary_cents: 300_000, started_on: Date.new(2024, 1, 10)) }

  before { sign_in user }

  def item(type, cents, **attrs)
    create(:payroll_item, employee: employee, year: 2026, month: 9, item_type: type, amount_cents: cents,
      occurred_on: Date.new(2026, 9, 10), **attrs)
  end

  describe "GET /payroll_statements/:id" do
    it "requires sign in" do
      sign_out user

      get payroll_statement_path(employee, year: 2026, month: 9)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists salary, bonuses, advances (with the installment), discounts, the net amount and the payment" do
      item("bonus", 20_000, notes: "Meta batida")
      item("advance", 30_000, installment_number: 1, installments_count: 3)
      item("discount", 10_000, notes: "Uniforme")
      item("salary_payment", 200_000, occurred_on: Date.new(2026, 9, 30))

      get payroll_statement_path(employee, year: 2026, month: 9)

      text = Nokogiri::HTML(response.body).text.squish
      expect(text).to include("Demonstrativo de pagamento", "Carlos Tratador", "Tratador", "Competência: 09/2026")
      expect(text).to include("Salário base 09/2026 R$ 3.000,00")
      expect(text).to include("Bônus (Meta batida) 10/09/2026 R$ 200,00", "Total de proventos R$ 3.200,00")
      expect(text).to include("Adiantamento — parcela 1/3 10/09/2026 - R$ 300,00")
      expect(text).to include("Desconto (Uniforme) 10/09/2026 - R$ 100,00", "Total de descontos - R$ 400,00")
      expect(text).to include("Líquido do mês R$ 2.800,00", "Pago em 30/09/2026 R$ 2.000,00", "Saldo a receber R$ 800,00")
      expect(text).not_to include("Adiantamento do 13º")
    end

    it "shows the 13th advance apart, without taking it out of the month's salary" do
      item("thirteenth_advance", 100_000)

      get payroll_statement_path(employee, year: 2026, month: 9)

      text = Nokogiri::HTML(response.body).text.squish
      expect(text).to include("Adiantamento do 13º salário", "Adiantamento 13º 10/09/2026 R$ 1.000,00")
      expect(text).to include("Líquido do mês R$ 3.000,00")
    end

    it "renders a PDF" do
      get payroll_statement_path(employee, year: 2026, month: 9, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("demonstrativo-carlos-tratador-2026-09.pdf")
    end

    it "is not found for an invalid month" do
      get payroll_statement_path(employee, year: 2026, month: 13)

      expect(response).to have_http_status(:not_found)
    end

    it "is blocked for a member whose profile cannot see the payroll" do
      sign_out user
      person = create(:user)
      company = create(:company, tenant_name: "public")
      profile = create(:access_profile, permission_matrix: { "dashboard" => %w[read], "__submitted" => "1" })
      create(:membership, user: person, company: company, role: "member", access_profile_id: profile.id)
      post user_session_path, params: { user: { tenant_name: "public", email: person.email, password: "password123" } }

      get payroll_statement_path(employee, year: 2026, month: 9)

      expect(response.body).not_to include("Demonstrativo de pagamento")
      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end

  describe "GET /shared/:tenant_name/payroll_statements/:id/:year/:month/:share_token" do
    it "renders the PDF publicly, without signing in" do
      sign_out user

      get shared_payroll_statement_pdf_path(tenant_name: "public", id: employee.id, year: 2026, month: 9,
        share_token: employee.share_token, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not found with a wrong token" do
      sign_out user

      get shared_payroll_statement_pdf_path(tenant_name: "public", id: employee.id, year: 2026, month: 9,
        share_token: "wrong", format: :pdf)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "buttons on the payroll page" do
    it "links each employee's card to the statement PDF of the competência" do
      employee

      get payroll_path(year: 2026, month: 9)

      hrefs = Nokogiri::HTML(response.body).css("a").map { |a| a["href"] }
      expect(hrefs).to include(payroll_statement_path(employee, year: 2026, month: 9, format: :pdf))
    end

    it "offers a WhatsApp link with the public PDF when a company is selected" do
      sign_out user
      company = create(:company, tenant_name: "public")
      create(:membership, user: user, company: company, role: "owner")
      post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }
      employee

      get payroll_path(year: 2026, month: 9)

      link = Nokogiri::HTML(response.body).css("a[href^='https://wa.me/']").map { |a| a["href"] }.first
      expect(link).to be_present
      expect(CGI.unescape(link)).to include("Demonstrativo de pagamento 09/2026 - Carlos Tratador")
      expect(CGI.unescape(link)).to include(
        shared_payroll_statement_pdf_url(tenant_name: "public", id: employee.id, year: 2026, month: 9,
          share_token: employee.reload.share_token, format: :pdf)
      )
    end
  end
end
