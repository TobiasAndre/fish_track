require "rails_helper"

# O log registra sempre quem fez a ação (o usuário logado no request), nunca um usuário fixo.
RSpec.describe "Activity log actor", type: :request do
  let(:company) { create(:company, tenant_name: "public") }

  def log_in(person, role:, matrix: nil)
    profile = matrix && create(:access_profile, permission_matrix: matrix.merge("__submitted" => "1"))
    create(:membership, user: person, company: company, role: role, access_profile_id: profile&.id)
    post user_session_path, params: { user: { tenant_name: "public", email: person.email, password: "password123" } }
  end

  def log_out
    delete destroy_user_session_path
  end

  def last_log_for(resource_type)
    ActivityLog.where(resource_type: resource_type).order(:id).last
  end

  it "records each person who acts, with their company and IP, whoever acted before" do
    admin = create(:user, name: "Administradora", system_admin: true)
    maria = create(:user, name: "Maria")
    joao = create(:user, name: "João")

    log_in(admin, role: "owner")
    post units_path, params: { unit: { name: "Feita pela admin" } }
    expect(last_log_for("Unit").user).to eq(admin)
    log_out

    log_in(maria, role: "member", matrix: { "units" => %w[read write edit] })
    post units_path, params: { unit: { name: "Feita pela Maria" } }
    expect(last_log_for("Unit")).to have_attributes(user: maria, company: company, action: "create")
    expect(last_log_for("Unit").ip_address).to be_present
    log_out

    Membership.where(user: maria).delete_all
    log_in(joao, role: "member", matrix: { "units" => %w[read edit] })
    unit = Unit.find_by(name: "Feita pela Maria")
    patch unit_path(unit), params: { unit: { name: "Editada pelo João" } }
    expect(last_log_for("Unit")).to have_attributes(user: joao, action: "update")

    expect(ActivityLog.where(resource_type: "Unit").pluck(:user_id)).to eq([admin.id, maria.id, joao.id])
  end

  it "records the administrator, not the edited user, when a user is changed in the admin area" do
    admin = create(:user, system_admin: true)
    target = create(:user, name: "Antigo")
    sign_in admin

    patch admin_user_path(target), params: { user: { name: "Novo nome" } }

    expect(last_log_for("User")).to have_attributes(user: admin, action: "update")
  end

  it "does not leak the previous request's user into a request made without login" do
    admin = create(:user, system_admin: true)
    log_in(admin, role: "owner")
    post units_path, params: { unit: { name: "Qualquer" } }
    log_out
    report = create(:report_share, report_type: "loading_report", filters: {})

    expect do
      get shared_loading_report_pdf_path(tenant_name: "public", id: report.id, share_token: report.share_token, format: :pdf)
    end.not_to change(ActivityLog, :count)
  end
end
