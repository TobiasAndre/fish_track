require "rails_helper"

RSpec.describe "AccessProfiles", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:company) { create(:company, name: "Piscicultura Azul", tenant_name: "public") }

  # sign_in do Devise não passa pelo seletor de empresa; o login real grava o tenant na sessão.
  def log_in_with_company(user, role: nil)
    sign_out user
    create(:membership, user: user, company: company, role: role) if role
    post user_session_path, params: { user: { tenant_name: "public", email: user.email, password: "password123" } }
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def profile_params(name: "Técnico de campo", matrix: { "biometry_events" => %w[read write], "units" => %w[read] })
    { access_profile: { name: name, description: "Lança biometria", permission_matrix: matrix.merge("__submitted" => "1") } }
  end

  describe "access control" do
    it "redirects to sign in when not authenticated" do
      get access_profiles_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "denies everyone who is not the system administrator, even the company owner and admin, on every action" do
      %w[member admin owner].each do |role|
        person = create(:user)
        log_in_with_company(person, role: role)
        profile = create(:access_profile, name: "Perfil #{role}")

        get access_profiles_path
        expect(response).to redirect_to(root_path), "#{role} should be denied"
        expect(flash[:alert]).to include("não tem permissão")

        get new_access_profile_path
        expect(response).to redirect_to(root_path)

        get edit_access_profile_path(profile)
        expect(response).to redirect_to(root_path)

        expect { post access_profiles_path, params: profile_params(name: "Novo #{role}") }.not_to change(AccessProfile, :count)
        expect(response).to redirect_to(root_path)

        patch access_profile_path(profile), params: profile_params(name: "Hack #{role}")
        expect(profile.reload.name).to eq("Perfil #{role}")

        expect { delete access_profile_path(profile) }.not_to change(AccessProfile, :count)
      end
    end

    it "allows the system administrator" do
      admin = create(:user, system_admin: true)
      log_in_with_company(admin, role: "member")

      get access_profiles_path

      expect(response).to have_http_status(:ok)
    end

    it "asks for a company when none is selected" do
      admin = create(:user, system_admin: true)
      sign_in admin

      get access_profiles_path

      expect(response).to redirect_to(select_company_path)
    end
  end

  context "as the system administrator" do
    let(:user) { create(:user, system_admin: true) }

    before { log_in_with_company(user, role: "member") }

    describe "GET /access_profiles" do
      it "lists the profiles with their permission count" do
        create(:access_profile, name: "Gerente", description: "Tudo", permission_matrix: { "units" => %w[read write], "ponds" => %w[read] })
        create(:access_profile, name: "Auditor")

        get access_profiles_path

        rows = doc.css("tbody tr").map { |tr| tr.text.gsub(/\s+/, " ").strip }
        expect(rows.first).to include("Auditor", "0")
        expect(rows.last).to include("Gerente", "Tudo", "3")
      end

      it "shows an empty state" do
        get access_profiles_path

        expect(response.body).to include("Nenhum perfil criado ainda.")
      end
    end

    describe "GET /access_profiles/new" do
      it "lists every page of the catalog with a checkbox per action it supports" do
        get new_access_profile_path

        expect(response).to have_http_status(:ok)
        PermissionCatalog.resources.each do |resource|
          row = doc.at_css("tr[data-resource='#{resource.key}']")
          expect(row).to be_present, "#{resource.label} is missing"
          expect(row.text).to include(resource.label)

          PermissionCatalog::ACTIONS.each do |action|
            box = row.at_css("input[type=checkbox][name='access_profile[permission_matrix][#{resource.key}][]'][value='#{action}']")
            expect(box.present?).to eq(resource.allows?(action)), "#{resource.key}/#{action}"
          end
        end
      end

      it "groups the pages and labels the four actions" do
        get new_access_profile_path

        groups = doc.css("tbody th[colspan]").map { |th| th.text.strip }
        expect(groups).to eq(["Geral", "Cadastros", "Lançamentos", "Relatórios"])
        header = doc.css("thead th").map { |th| th.text.gsub(/\s+/, " ").strip }
        expect(header).to include(a_string_including("Visualizar"), a_string_including("Criar"), a_string_including("Editar"), a_string_including("Excluir"))
      end

      it "renders a dash where a page doesn't support an action" do
        get new_access_profile_path

        row = doc.at_css("tr[data-resource='dashboard']")
        expect(row.css("input[type=checkbox][data-permission-matrix-target=box]").size).to eq(1)
        expect(row.css("td").map { |td| td.text.strip }).to include("—")
      end

      it "wires the matrix controller and the submitted marker" do
        get new_access_profile_path

        expect(doc.at_css("[data-controller='permission-matrix']")).to be_present
        expect(doc.at_css("input[type=hidden][name='access_profile[permission_matrix][__submitted]']")["value"]).to eq("1")
      end
    end

    describe "POST /access_profiles" do
      it "creates the profile with the checked permissions" do
        expect { post access_profiles_path, params: profile_params }.to change(AccessProfile, :count).by(1)

        profile = AccessProfile.last
        expect(profile).to have_attributes(name: "Técnico de campo", description: "Lança biometria")
        expect(profile.permission_map).to eq("biometry_events" => %w[read write], "units" => %w[read])
        expect(response).to redirect_to(access_profiles_path)
      end

      it "creates a profile with no permission at all" do
        post access_profiles_path, params: { access_profile: { name: "Vazio", permission_matrix: { "__submitted" => "1" } } }

        expect(AccessProfile.find_by(name: "Vazio").permissions).to be_empty
      end

      it "adds read when only write/edit/delete were sent" do
        post access_profiles_path, params: profile_params(matrix: { "ponds" => %w[delete] })

        expect(AccessProfile.last.permission_map["ponds"]).to contain_exactly("read", "delete")
      end

      it "ignores unknown pages and forbidden actions sent by hand" do
        post access_profiles_path, params: profile_params(matrix: { "hack" => %w[read], "dashboard" => %w[delete], "units" => %w[read] })

        expect(AccessProfile.last.permission_map).to eq("units" => %w[read])
      end

      it "shows the errors and keeps the checked boxes when the name is missing" do
        expect { post access_profiles_path, params: profile_params(name: "") }.not_to change(AccessProfile, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Corrija os erros abaixo")
        checked = doc.css("input[type=checkbox][checked]").map { |i| i["id"] }
        expect(checked).to include("permission_biometry_events_read", "permission_biometry_events_write", "permission_units_read")
      end

      it "rejects a repeated name" do
        create(:access_profile, name: "Técnico de campo")

        expect { post access_profiles_path, params: profile_params(name: "técnico de campo") }.not_to change(AccessProfile, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "editing" do
      let!(:profile) { create(:access_profile, name: "Antigo", permission_matrix: { "units" => %w[read write], "ponds" => %w[read] }) }

      it "pre-checks the profile's permissions" do
        get edit_access_profile_path(profile)

        checked = doc.css("input[type=checkbox][checked]").map { |i| i["id"] }
        expect(checked).to contain_exactly("permission_units_read", "permission_units_write", "permission_ponds_read")
        expect(doc.at_css("input#access_profile_name")["value"]).to eq("Antigo")
      end

      it "updates the name and the permissions" do
        patch access_profile_path(profile), params: profile_params(name: "Novo", matrix: { "units" => %w[read edit], "silos" => %w[read] })

        profile.reload
        expect(profile.name).to eq("Novo")
        expect(profile.permission_map).to eq("units" => %w[read edit], "silos" => %w[read])
        expect(response).to redirect_to(access_profiles_path)
      end

      it "clears the permissions when every box is unchecked" do
        patch access_profile_path(profile), params: { access_profile: { name: "Antigo", permission_matrix: { "__submitted" => "1" } } }

        expect(profile.reload.permissions).to be_empty
      end

      it "keeps the permissions when the request carries no matrix" do
        patch access_profile_path(profile), params: { access_profile: { name: "Renomeado" } }

        expect(profile.reload.permission_map).to eq("units" => %w[read write], "ponds" => %w[read])
      end

      it "shows the errors and changes nothing when invalid" do
        patch access_profile_path(profile), params: profile_params(name: "", matrix: { "silos" => %w[read] })

        expect(response).to have_http_status(:unprocessable_content)
        expect(profile.reload.permission_map).to eq("units" => %w[read write], "ponds" => %w[read])
      end
    end

    describe "DELETE /access_profiles/:id" do
      it "removes the profile and its permissions" do
        profile = create(:access_profile, permission_matrix: { "units" => %w[read write] })

        expect { delete access_profile_path(profile) }.to change(AccessProfile, :count).by(-1).and change(AccessProfilePermission, :count).by(-2)
        expect(response).to redirect_to(access_profiles_path)
      end

      it "refuses to remove a profile that is assigned to users of the company" do
        profile = create(:access_profile, permission_matrix: { "units" => %w[read] })
        create(:membership, company: company, role: "member", access_profile_id: profile.id)

        expect { delete access_profile_path(profile) }.not_to change(AccessProfile, :count)
        expect(response).to redirect_to(access_profiles_path)
        expect(flash[:alert]).to include("atribuído a usuários")
      end
    end

    it "shows the menu entry, in the admin-only Administração section" do
      get access_profiles_path

      section = doc.css("nav p").find { |p| p.text.strip == "Administração" }
      expect(section).to be_present
      expect(doc.css("a[href='#{access_profiles_path}']").map(&:text).join).to include("Perfis de acesso")
    end
  end

  it "hides the menu entry from everyone else, even the company owner" do
    owner = create(:user)
    log_in_with_company(owner, role: "owner")

    get units_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cadastros") # a barra lateral foi renderizada
    expect(response.body).not_to include(access_profiles_path)
    expect(response.body).not_to include("Perfis de acesso")
  end
end
