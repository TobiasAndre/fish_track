require "rails_helper"

# O formulário de biometria formata a digitação em pt-BR ("." = milhar, "," =
# decimal). Os pesos já salvos precisam aparecer nesse formato na edição, senão
# "12.5" vira "125" ao mexer no campo.
RSpec.describe "Biometry form decimal fields", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:batch) { create(:batch, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:batch_stocking) { batch.batch_stockings.first }

  before { sign_in user }

  def field_value(name)
    Nokogiri::HTML(response.body).at_css("input[name='stocking_event[#{name}]']")["value"]
  end

  it "shows the saved weights in the Brazilian format when editing" do
    event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking, total_weight_kg: 1234.5, feed_kg: 12.5)

    get edit_biometry_event_path(event)

    expect(field_value("total_weight_kg")).to eq("1.234,5")
    expect(field_value("feed_kg")).to eq("12,5")
  end

  it "stores the weights sent without thousand separators (as the form now submits them)" do
    post biometry_events_path, params: {
      stocking_event: { batch_stocking_id: batch_stocking.id, occurred_on: Date.current, volume: "1.000", quantity: "50",
                        total_weight_kg: "1234,5", feed_kg: "1500" }
    }

    event = StockingEvent.where(event_type: "biometrics").order(:id).last
    expect(event.total_weight_kg).to eq(1234.5)
    expect(event.feed_kg).to eq(1500)
  end

  it "wires the form to strip the thousand separators before submitting" do
    get biometry_events_path(batch_stocking_id: batch_stocking.id)

    form = Nokogiri::HTML(response.body).at_css("form[data-controller='biometry-form']")
    expect(form["data-action"]).to include("submit->biometry-form#normalizeBeforeSubmit")
  end
end
