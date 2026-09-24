require "rails_helper"

RSpec.describe "shared/_flash", type: :view do
  def toasts
    Nokogiri::HTML(rendered).css('[data-controller="flash"]')
  end

  it "renders nothing without a notice or alert" do
    allow(view).to receive_messages(notice: nil, alert: nil)

    render partial: "shared/flash"

    expect(toasts).to be_empty
  end

  it "renders a success toast for a notice and an error toast for an alert" do
    allow(view).to receive_messages(notice: "Salvo!", alert: "Falhou!")

    render partial: "shared/flash"

    expect(toasts.map { |t| [t["data-flash-type-value"], t["data-flash-message-value"]] })
      .to eq([["success", "Salvo!"], ["error", "Falhou!"]])
  end

  it "keeps the toast out of Turbo's page cache so it doesn't repeat on Back" do
    allow(view).to receive_messages(notice: "Salvo!", alert: nil)

    render partial: "shared/flash"

    expect(toasts.sole).to have_attribute("data-turbo-temporary")
    expect(toasts.sole).to have_attribute("hidden")
  end

  it "escapes the message so it can't break out of the attribute or inject markup" do
    payload = %(x"><img src=x onerror=alert(1)>)
    allow(view).to receive_messages(notice: payload, alert: nil)

    render partial: "shared/flash"

    expect(rendered).not_to include("<img")
    expect(toasts.sole["data-flash-message-value"]).to eq(payload)
  end
end
