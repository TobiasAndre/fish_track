require "rails_helper"

RSpec.describe "Flash messages", type: :request do
  let(:user) { create(:user, system_admin: true) }

  def flash_elements
    Nokogiri::HTML(response.body).css('[data-controller="flash"]')
  end

  it "shows a success notice on the logged-in pages, as data for the flash controller and not as inline JavaScript" do
    sign_in user

    post financial_entries_path, params: {
      financial_entry: { entry_type: "expense", stage: "general", occurred_on: Date.current,
                         amount_cents: 1_000, description: "Toast", mark_settled: "0" }
    }
    follow_redirect!

    toast = flash_elements.sole
    expect(toast["data-flash-type-value"]).to eq("success")
    expect(toast["data-flash-message-value"]).to eq("Lançamento criado!")
    expect(response.body).not_to include("Swal.fire")
  end

  it "shows an alert as an error toast on the login page" do
    get root_path
    follow_redirect!

    toast = flash_elements.sole
    expect(toast["data-flash-type-value"]).to eq("error")
    expect(toast["data-flash-message-value"]).to be_present
  end

  it "shows a toast only once per page" do
    sign_in user

    patch settle_financial_entry_path(create(:financial_entry))
    follow_redirect!

    expect(flash_elements.size).to eq(1)
  end
end
