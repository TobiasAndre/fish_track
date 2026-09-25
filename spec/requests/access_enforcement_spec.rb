require "rails_helper"

# O perfil de acesso decide o que um membro da empresa enxerga (menu e botões)
# e o que consegue fazer (o servidor barra o resto, mesmo digitando a URL).
RSpec.describe "Access profile enforcement", type: :request do
  let(:company) { create(:company, name: "Piscicultura Azul", tenant_name: "public") }
  let(:person) { create(:user, name: "Maria") }

  # O login real grava a empresa na sessão (sign_in do Devise não passa pelo seletor).
  def log_in_as(role:, matrix: nil)
    profile = matrix && create(:access_profile, permission_matrix: matrix.merge("__submitted" => "1"))
    create(:membership, user: person, company: company, role: role, access_profile_id: profile&.id)
    post user_session_path, params: { user: { tenant_name: "public", email: person.email, password: "password123" } }
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def menu_links
    doc.css("nav a").map { |a| a["href"] }
  end

  describe "who keeps full access" do
    it "lets the system administrator see everything, with or without membership" do
      admin = create(:user, system_admin: true)
      sign_in admin

      get units_path
      expect(response).to have_http_status(:ok)
      expect(doc.text).to include("Nova unidade")
    end

    %w[owner admin].each do |role|
      it "lets a company #{role} see and do everything" do
        log_in_as(role: role)
        unit = create(:unit)

        get units_path
        expect(response).to have_http_status(:ok)
        expect(doc.text).to include("Nova unidade")
        expect(doc.at_css("a[href='#{edit_unit_path(unit)}']")).to be_present
        expect(doc.at_css("form[action='#{unit_path(unit)}'] button")).to be_present
        expect(menu_links).to include(ponds_path, financial_entries_path, batch_reports_path)

        expect { post units_path, params: { unit: { name: "Nova" } } }.to change(Unit, :count).by(1)
      end
    end
  end

  describe "a member with a read-only profile" do
    before { log_in_as(role: "member", matrix: { "dashboard" => %w[read], "units" => %w[read] }) }

    let!(:unit) { create(:unit, name: "Unidade Norte") }

    it "sees the page and its data, but not the New, Edit and Delete buttons" do
      get units_path

      expect(response).to have_http_status(:ok)
      expect(doc.text).to include("Unidade Norte")
      expect(doc.text).not_to include("Nova unidade")
      expect(doc.at_css("a[href='#{new_unit_path}']")).to be_nil
      expect(doc.at_css("a[href='#{edit_unit_path(unit)}']")).to be_nil
      expect(doc.at_css("form[action='#{unit_path(unit)}']")).to be_nil
    end

    it "only has the permitted pages in the menu" do
      get units_path

      expect(menu_links).to include(units_path, root_path)
      expect(menu_links).not_to include(ponds_path, silos_path, financial_entries_path, batches_path, batch_reports_path)
    end

    it "hides the menu groups it has no page in" do
      get units_path

      expect(doc.css("nav").text).to include("Cadastros")
      expect(doc.css("nav").text).not_to include("Lançamentos")
      expect(doc.css("nav").text).not_to include("Relatórios")
    end

    it "is turned away from a page it has no permission for" do
      get ponds_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("não tem permissão")
    end

    it "cannot open the new or edit forms, nor create, update or delete by hand" do
      get new_unit_path
      expect(response).to redirect_to(root_path)

      get edit_unit_path(unit)
      expect(response).to redirect_to(root_path)

      expect { post units_path, params: { unit: { name: "Invasora" } } }.not_to change(Unit, :count)
      expect(response).to redirect_to(root_path)

      patch unit_path(unit), params: { unit: { name: "Renomeada" } }
      expect(unit.reload.name).to eq("Unidade Norte")

      expect { delete unit_path(unit) }.not_to change(Unit, :count)
    end

    it "answers non-page formats with 403 instead of redirecting" do
      get ponds_path(format: :json)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "granting each action separately" do
    it "shows New and allows creating with write permission only" do
      log_in_as(role: "member", matrix: { "units" => %w[write] })
      unit = create(:unit)

      get units_path
      expect(doc.at_css("a[href='#{new_unit_path}']")).to be_present
      expect(doc.at_css("a[href='#{edit_unit_path(unit)}']")).to be_nil

      get new_unit_path
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("input[type=submit][value=Salvar]")).to be_present

      expect { post units_path, params: { unit: { name: "Criada" } } }.to change(Unit, :count).by(1)
    end

    it "shows Edit and allows updating with edit permission only" do
      log_in_as(role: "member", matrix: { "units" => %w[edit] })
      unit = create(:unit, name: "Antes")

      get units_path
      expect(doc.at_css("a[href='#{edit_unit_path(unit)}']")).to be_present
      expect(doc.at_css("a[href='#{new_unit_path}']")).to be_nil

      patch unit_path(unit), params: { unit: { name: "Depois" } }
      expect(unit.reload.name).to eq("Depois")

      expect { post units_path, params: { unit: { name: "Nova" } } }.not_to change(Unit, :count)
    end

    it "shows Delete and allows deleting with delete permission only" do
      log_in_as(role: "member", matrix: { "units" => %w[delete] })
      unit = create(:unit)

      get units_path
      expect(doc.at_css("form[action='#{unit_path(unit)}']")).to be_present
      expect(doc.at_css("a[href='#{edit_unit_path(unit)}']")).to be_nil

      expect { delete unit_path(unit) }.to change(Unit, :count).by(-1)
    end
  end

  describe "entry forms that live on a list page" do
    it "hide the whole form from who can only read, and show it with write permission" do
      log_in_as(role: "member", matrix: { "silo_stock_entries" => %w[read] })
      get silo_stock_entries_path
      expect(response).to have_http_status(:ok)
      expect(doc.text).not_to include("Nova entrada de estoque")
      expect(doc.at_css("input[type=submit]")).to be_nil

      Membership.find_by(user_id: person.id).update!(
        access_profile_id: create(:access_profile, permission_matrix: { "silo_stock_entries" => %w[read write], "__submitted" => "1" }).id
      )
      get silo_stock_entries_path
      expect(doc.text).to include("Nova entrada de estoque")
    end
  end

  describe "a member who cannot see any page" do
    it "with a profile that grants nothing gets the no-access page" do
      log_in_as(role: "member", matrix: {})

      get root_path

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Sem acesso")
      expect(menu_links).not_to include(units_path, batches_path, financial_entries_path)
    end

    it "without a profile gets the no-access page too" do
      log_in_as(role: "member")

      get units_path

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Sem acesso")
    end

    it "with a profile that points to a deleted one gets no access (fails closed)" do
      create(:membership, user: person, company: company, role: "member", access_profile_id: 424_242)
      post user_session_path, params: { user: { tenant_name: "public", email: person.email, password: "password123" } }

      get units_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "without a company selected" do
    it "sends a non-admin to choose a company instead of showing pages" do
      sign_in person

      get units_path

      expect(response).to redirect_to(select_company_path)
    end
  end

  describe "the dashboard" do
    # O dashboard exige uma empresa escolhida (tenant diferente de "public").
    before { allow(Apartment::Tenant).to receive(:current).and_return("acme") }

    let(:finance_labels) { ["Despesa total", "Faturamento total", "Saldo financeiro", "A pagar", "A receber"] }

    it "hides the financial figures from who cannot read the financial page" do
      log_in_as(role: "member", matrix: { "dashboard" => %w[read], "batches" => %w[read] })

      get root_path

      expect(response).to have_http_status(:ok)
      expect(doc.text).to include("Peixes alojados")
      finance_labels.each { |label| expect(doc.text).not_to include(label) }
    end

    it "shows the financial figures to who can read the financial page" do
      log_in_as(role: "member", matrix: { "dashboard" => %w[read], "batches" => %w[read], "financial_entries" => %w[read] })

      get root_path

      finance_labels.each { |label| expect(doc.text).to include(label) }
    end
  end

  describe "public share links" do
    it "keep working without any login or profile" do
      get shared_simulation_pdf_path(tenant_name: "public", id: 0, share_token: "nope", format: :pdf)

      expect(response).not_to redirect_to(new_user_session_path)
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  describe "generating a report share link" do
    it "needs only read permission on the report" do
      log_in_as(role: "member", matrix: { "batch_reports" => %w[read] })

      post create_share_batch_reports_path, params: {}

      expect(response).not_to redirect_to(root_path)
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
