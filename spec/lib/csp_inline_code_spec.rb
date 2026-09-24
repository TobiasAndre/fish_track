require "rails_helper"

# A CSP (script-src 'self', nonce só nos scripts do layout) é imposta pelo
# navegador: um <script> inline ou um onclick="..." simplesmente não roda, sem
# erro no servidor -- nenhum request spec percebe. Este guard barra o padrão na
# origem. Use Stimulus (data-controller / data-action) em vez de código inline.
RSpec.describe "Content-Security-Policy: no inline code in views" do
  views = Dir[Rails.root.join("app/views/**/*.erb")].reject { |f| f.include?("/layouts/mailer") }

  it "has views to check" do
    expect(views).not_to be_empty
  end

  it "has no <script> tag without a nonce or src" do
    offenders = views.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        "#{file.delete_prefix("#{Rails.root}/")}:#{index + 1}" if line.match?(/<script(?![^>]*\b(?:nonce|src)\b)/)
      end
    end

    expect(offenders).to be_empty, "inline <script> blocked by the CSP:\n#{offenders.join("\n")}"
  end

  it "has no inline event handler attributes (onclick=, onchange:, ...)" do
    offenders = views.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next unless line.match?(/\son(?:click|change|submit|input|blur|focus|load|keyup|keydown|mouseover)\s*=\s*["']/i) ||
                    line.match?(/\bon(?:click|change|submit|input|blur|focus|load|keyup|keydown|mouseover):\s*["']/)

        "#{file.delete_prefix("#{Rails.root}/")}:#{index + 1}"
      end
    end

    expect(offenders).to be_empty, "inline event handler blocked by the CSP:\n#{offenders.join("\n")}"
  end
end
