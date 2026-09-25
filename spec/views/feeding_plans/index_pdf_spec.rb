require "rails_helper"

RSpec.describe "feeding_plans/index.pdf.erb", type: :view do
  let(:unit) { create(:unit, name: "Sede") }
  let(:pond_4) { create(:pond, unit: unit, name: "Tanque 4", order_number: 1) }
  let(:pond_7) { create(:pond, unit: unit, name: "Tanque 7", order_number: 2) }
  let(:feeding_table) { create(:feeding_table, name: "Tabela Sede") }
  let!(:temp_range) { create(:feeding_temperature_range, temperature_from: 24, temperature_to: 26) }
  let!(:weight_range) { create(:feeding_weight_range, weight_from: 3, weight_to: 9.9) }

  before do
    create(:feeding_strategy_item, feeding_table: feeding_table, feeding_weight_range: weight_range,
                                   feeding_temperature_range: temp_range, feeding_percentage: 6.0)
    [[pond_4, 6_900, 900_000], [pond_7, 3_000, 400_000]].each do |pond, biomass, quantity|
      create(:batch, pond: pond, stocking_quantity: quantity, stocking_avg_weight_g: 7.0)
        .batch_stockings.first.update_columns(current_biomass_kg: biomass, current_quantity: quantity)
    end
    pond_4.update!(feed_sample_kg: 650, feed_sample_seconds: 964)
  end

  def render_pdf(ponds:, selected_ids: [], batch: nil)
    assign(:feeding_table, feeding_table)
    assign(:units, [unit])
    assign(:selected_unit_id, unit.id.to_s)
    assign(:selected_batch, batch)
    assign(:selected_pond_ids, selected_ids.map(&:to_s))
    assign(:ponds, ponds)
    assign(:plan, FeedingPlan.new(feeding_table: feeding_table, ponds: ponds))
    assign(:generated_at, Time.zone.local(2026, 9, 25, 14, 30))
    render template: "feeding_plans/index", formats: [:pdf]
  end

  it "prints the filters used and both tables with every temperature range" do
    render_pdf(ponds: [pond_4, pond_7])

    expect(rendered).to include("Arraçoamento", "Gerado em 25/09/2026 14:30")
    expect(rendered).to include("Tabela Sede", "Sede", "Todos")
    expect(rendered).to include("Trato (Kg) por temperatura", "Tempo (min) por temperatura", "24-26°C")
    expect(rendered).to include("Tanque 4", "Tanque 7")
  end

  it "shows the computed ration and time (6.900 kg x 6% = 414 kg; 414 kg x 1,483 s/kg = 10,2 min)" do
    render_pdf(ponds: [pond_4])

    expect(rendered).to include("900.000", "6.900", "7,67", "414")
    expect(rendered).to include("1,483", "10,2")
  end

  it "lists only the selected tanks and names them in the filters" do
    render_pdf(ponds: [pond_7], selected_ids: [pond_7.id])

    expect(rendered).to include("Tanque 7")
    expect(rendered).not_to include("Tanque 4")
    expect(rendered).to include("<td>Tanque 7</td>", "Tanques")
  end

  it "starts the time table on a new page, so it is always the second page" do
    render_pdf(ponds: [pond_4, pond_7])

    doc = Nokogiri::HTML(rendered)
    expect(rendered).to include("page-break-before: always")
    expect(doc.at_css(".section-title.new-page").text).to eq("Tempo (min) por temperatura")
    expect(doc.css(".new-page").size).to eq(1)
    expect(doc.at_css(".section-title", text: "Trato (Kg) por temperatura")["class"]).not_to include("new-page")
  end

  it "keeps a table row from being split across pages" do
    render_pdf(ponds: [pond_4])

    expect(rendered).to match(/tr\s*\{\s*page-break-inside:\s*avoid/)
  end

  it "shows a notice when there is no tank" do
    render_pdf(ponds: [])

    expect(rendered).to include("Nenhum tanque encontrado para o filtro selecionado.")
    expect(rendered).not_to include("Tempo (min) por temperatura")
  end

  it "names the lote when one was chosen" do
    lote = create(:batch, name: "Lote Azul", pond: pond_4)

    render_pdf(ponds: [pond_4], batch: lote)

    expect(rendered).to include("Lote Azul")
  end
end
