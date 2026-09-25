require "rails_helper"

RSpec.describe PermissionCatalog do
  it "defines the four actions" do
    expect(described_class::ACTIONS).to eq(%w[read write edit delete])
    expect(described_class::ACTION_LABELS.keys).to eq(described_class::ACTIONS)
  end

  it "has unique resource keys and lists every page grouped" do
    keys = described_class.resources.map(&:key)

    expect(keys).to eq(keys.uniq)
    expect(described_class.groups.map(&:label)).to eq(%w[Geral Cadastros Lançamentos Relatórios])
  end

  it "only uses known actions, and every page can at least be viewed" do
    described_class.resources.each do |resource|
      expect(resource.actions - described_class::ACTIONS).to be_empty, "#{resource.key} has unknown actions"
      expect(resource.actions).to include("read"), "#{resource.key} can't be viewed"
    end
  end

  it "gives the read-only pages (dashboard and reports) only the read action" do
    %w[dashboard batch_reports loading_reports batch_results].each do |key|
      expect(described_class.find(key).actions).to eq(%w[read])
    end
    expect(described_class.find("feeding_plans").actions).to eq(%w[read edit])
    expect(described_class.find("units").actions).to eq(described_class::ACTIONS)
  end

  it "knows what is valid for a page" do
    expect(described_class.valid?("units", "delete")).to be(true)
    expect(described_class.valid?("dashboard", "delete")).to be(false)
    expect(described_class.valid?("nope", "read")).to be(false)
    expect(described_class.valid?("units", "fly")).to be(false)
  end

  it "maps controllers to their page, and a controller belongs to a single page" do
    expect(described_class.resource_for_controller("employee_vacations").key).to eq("employees")
    expect(described_class.resource_for_controller("financial_payments").key).to eq("financial_entries")
    expect(described_class.resource_for_controller("payroll_items").key).to eq("payroll")
    expect(described_class.resource_for_controller("tenant_selections")).to be_nil

    controllers = described_class.covered_controllers
    expect(controllers).to eq(controllers.uniq)
  end

  # Barreira contra esquecimento: uma página nova precisa entrar no catálogo (ou ser
  # marcada como fora dele), senão ela ficaria sem permissão configurável.
  it "covers every controller of the app's routes (or excludes it explicitly)" do
    routed = Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq

    business = routed.reject do |controller|
      described_class::EXCLUDED_CONTROLLERS.include?(controller) ||
        described_class::EXCLUDED_PREFIXES.any? { |prefix| controller.start_with?(prefix) }
    end

    missing = business - described_class.covered_controllers
    expect(missing).to be_empty, "Add these controllers to PermissionCatalog (or EXCLUDED_CONTROLLERS): #{missing.join(', ')}"
  end

  it "doesn't list controllers that don't exist any more" do
    routed = Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq

    expect(described_class.covered_controllers - routed).to be_empty
  end
end
