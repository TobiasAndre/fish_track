require "rails_helper"

RSpec.describe "Devise messages", type: :request do
  let(:user) { create(:user, system_admin: true) }

  it "shows the failed-login message in Portuguese instead of a missing translation" do
    company = create(:company, tenant_name: "public")
    create(:membership, user: user, company: company, role: "owner")

    post user_session_path, params: { user: { email: user.email, password: "wrong", tenant_name: "public" } }
    follow_redirect! if response.redirect?

    expect(response.body).to include("E-mail ou senha inválidos.")
    expect(response.body).not_to include("Translation missing")
  end

  it "asks for login in Portuguese when the visitor isn't authenticated" do
    get root_path
    follow_redirect!

    expect(response.body).to include("Você precisa entrar antes de continuar.")
  end

  it "has no missing pt-BR translation for any message the app's Devise modules can show" do
    keys = %w[
      failure.already_authenticated failure.inactive failure.invalid failure.locked failure.last_attempt
      failure.not_found_in_database failure.timeout failure.unauthenticated
      sessions.signed_in sessions.signed_out sessions.already_signed_out
      passwords.no_token passwords.send_instructions passwords.send_paranoid_instructions passwords.updated passwords.updated_not_active
      registrations.destroyed registrations.signed_up registrations.signed_up_but_inactive registrations.signed_up_but_locked
      registrations.updated registrations.updated_but_not_signed_in
      unlocks.send_instructions unlocks.send_paranoid_instructions unlocks.unlocked
      mailer.reset_password_instructions.subject mailer.unlock_instructions.subject
      mailer.email_changed.subject mailer.password_change.subject
    ]

    missing = keys.reject { |key| I18n.exists?("devise.#{key}", :"pt-BR") }

    expect(missing).to be_empty
  end
end
