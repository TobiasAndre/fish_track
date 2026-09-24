require "rails_helper"

RSpec.describe "PWA", type: :request do
  def png_size(path)
    File.binread(path, 24).unpack("x16N2")
  end

  describe "GET /manifest.json" do
    it "is public and describes an installable standalone app" do
      get pwa_manifest_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      manifest = JSON.parse(response.body)
      expect(manifest).to include(
        "name" => "Fish Track", "short_name" => "Fish Track",
        "start_url" => "/", "scope" => "/", "display" => "standalone", "lang" => "pt-BR"
      )
      expect(manifest["theme_color"]).to match(/\A#\h{6}\z/)
      expect(manifest["background_color"]).to match(/\A#\h{6}\z/)
    end

    it "declares 192px and 512px icons plus a maskable one, and every icon file exists at that size" do
      get pwa_manifest_path(format: :json)

      icons = JSON.parse(response.body)["icons"]
      expect(icons.map { |i| [i["sizes"], i["purpose"]] }).to include(["192x192", "any"], ["512x512", "any"], ["512x512", "maskable"])

      icons.each do |icon|
        path = Rails.public_path.join(icon["src"].delete_prefix("/"))
        expect(File).to exist(path), "#{icon['src']} is missing"
        expect(png_size(path)).to eq(icon["sizes"].split("x").map(&:to_i))
      end
    end

    it "offers a home-screen shortcut straight to Biometria" do
      get pwa_manifest_path(format: :json)

      shortcut = JSON.parse(response.body)["shortcuts"].sole
      expect(shortcut).to include("name" => "Biometria", "url" => biometry_events_path)
    end
  end

  describe "GET /service-worker" do
    it "is public and served as JavaScript from the root scope" do
      get pwa_service_worker_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to match(%r{javascript})
      expect(response.body).to include('addEventListener("fetch"')
    end

    it "never caches the app's authenticated pages: only navigations fall back to the offline page" do
      get pwa_service_worker_path

      expect(response.body).to include("OFFLINE_URL", "/offline.html")
      expect(response.body).to include('request.method !== "GET"')
      expect(response.body).to include('request.mode === "navigate"')
    end

    it "versions its cache so a changed offline page or icon replaces the old cache" do
      get pwa_service_worker_path

      expect(response.body[/const VERSION = "(\h+)"/, 1]).to match(/\A\h{12}\z/)
      expect(response.body).to include("fishtrack-static-${VERSION}", "caches.delete(key)")
    end
  end

  describe "offline page" do
    it "exists as a static, self-contained page" do
      html = File.read(Rails.public_path.join("offline.html"))

      expect(html).to include("Sem conexão", "Tentar novamente")
      expect(html).not_to match(/<script/i)
    end
  end

  describe "layout" do
    it "links the manifest, theme color and apple touch icon on the login page" do
      get new_user_session_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('link[rel="manifest"]')["href"]).to eq("/manifest.json")
      expect(doc.at_css('meta[name="theme-color"]')["content"]).to eq("#4f46e5")
      expect(doc.at_css('link[rel="apple-touch-icon"]')["href"]).to eq("/apple-touch-icon.png")
      expect(doc.at_css('meta[name="apple-mobile-web-app-capable"]')["content"]).to eq("yes")
    end

    it "loads the service worker registration script" do
      get new_user_session_path

      expect(response.body).to match(%r{"pwa":\s*"/assets/pwa-})
    end

    it "keeps the apple touch icons non-empty PNGs" do
      %w[apple-touch-icon.png apple-touch-icon-precomposed.png].each do |file|
        expect(png_size(Rails.public_path.join(file))).to eq([180, 180])
      end
    end
  end
end
