require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, system_admin: true) }

  before { sign_in admin }

  describe "GET /admin/users" do
    it "lists users" do
      user = create(:user, name: "Fulano de Tal")

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fulano de Tal")
    end
  end

  describe "POST /admin/users" do
    it "creates a user with valid params" do
      expect do
        post admin_users_path, params: {
          user: {
            name: "Novo usuário",
            email: "novo@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(admin_users_path)
    end

    it "does not create a user with mismatched password confirmation" do
      expect do
        post admin_users_path, params: {
          user: {
            name: "Novo usuário",
            email: "novo@example.com",
            password: "password123",
            password_confirmation: "different"
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /admin/users/:id" do
    it "updates the user's name without requiring a password" do
      user = create(:user, name: "Old name")

      patch admin_user_path(user), params: { user: { name: "New name", password: "", password_confirmation: "" } }

      expect(response).to redirect_to(admin_users_path)
      expect(user.reload.name).to eq("New name")
    end
  end

  describe "company access and access profile" do
    let(:company) { create(:company, name: "Piscicultura Azul", tenant_name: "public") }
    let!(:profile) { create(:access_profile, name: "Técnico", permission_matrix: { "units" => %w[read] }) }
    let(:person) { create(:user) }

    def membership
      Membership.find_by(user_id: person.id, company_id: company.id)
    end

    def memberships_params(enabled: "1", role: "member", profile_id: profile.id)
      { memberships: { company.id.to_s => { enabled: enabled, role: role, access_profile_id: profile_id.to_s } } }
    end

    it "lists each company with its role and the profiles of that company on the edit form" do
      company
      get edit_admin_user_path(person)

      html = Nokogiri::HTML(response.body)
      expect(html.text).to include("Piscicultura Azul")
      expect(html.css("select[name='memberships[#{company.id}][role]'] option").map(&:text)).to eq(%w[Proprietário Administrador Membro])
      expect(html.css("select[name='memberships[#{company.id}][access_profile_id]'] option").map(&:text)).to include("Técnico")
    end

    it "gives a user access to a company as a member with a profile" do
      patch admin_user_path(person), params: { user: { name: "Maria" } }.merge(memberships_params)

      expect(membership.role).to eq("member")
      expect(membership.access_profile_id).to eq(profile.id)
    end

    it "changes the role and profile of an existing access" do
      create(:membership, user: person, company: company, role: "member", access_profile_id: profile.id)

      patch admin_user_path(person), params: { user: { name: "Maria" } }.merge(memberships_params(role: "admin"))

      expect(membership.role).to eq("admin")
      expect(membership.access_profile_id).to be_nil, "owners and admins do not use a profile"
    end

    it "ignores a profile id that does not exist in the company" do
      patch admin_user_path(person), params: { user: { name: "Maria" } }.merge(memberships_params(profile_id: 999_999))

      expect(membership.access_profile_id).to be_nil
    end

    it "removes the access when the company is unchecked" do
      create(:membership, user: person, company: company, role: "member", access_profile_id: profile.id)

      patch admin_user_path(person), params: { user: { name: "Maria" } }.merge(memberships_params(enabled: "0"))

      expect(membership).to be_nil
    end

    it "leaves the accesses alone when the form sent no company section" do
      create(:membership, user: person, company: company, role: "member", access_profile_id: profile.id)

      patch admin_user_path(person), params: { user: { name: "Maria" } }

      expect(membership.access_profile_id).to eq(profile.id)
    end

    it "grants access to companies when creating the user" do
      post admin_users_path, params: {
        user: { name: "Nova", email: "nova@example.com", password: "password123", password_confirmation: "password123" }
      }.merge(memberships_params)

      created = User.find_by(email: "nova@example.com")
      expect(Membership.find_by(user_id: created.id, company_id: company.id).access_profile_id).to eq(profile.id)
    end
  end
end
