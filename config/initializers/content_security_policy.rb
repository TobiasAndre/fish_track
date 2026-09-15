# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data, "https://cdnjs.cloudflare.com"
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    # `unsafe_inline` here (not on script_src) covers the app's many
    # inline style="" attributes (print/report views especially).
    # Font Awesome's stylesheet is loaded from cdnjs in the main layout.
    policy.style_src   :self, :unsafe_inline, "https://cdnjs.cloudflare.com"
    # The CEP (postal code) autofill controller calls viacep.com.br directly.
    policy.connect_src :self, "https://viacep.com.br"
    policy.base_uri    :self
    policy.form_action :self
  end

  # Generate a per-request nonce for permitted importmap and inline scripts.
  # `request.session.id` (the Rails guide's suggested generator) is blank on
  # a visitor's very first request (no session cookie yet), which produces
  # an invalid `'nonce-'` source and silently blocks every inline script
  # -- including the Turbo/Stimulus importmap bootstrap. SecureRandom avoids
  # that failure mode entirely; Rails already memoizes it per request.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src)
end
