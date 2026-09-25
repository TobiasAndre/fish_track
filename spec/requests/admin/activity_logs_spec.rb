require "rails_helper"

RSpec.describe "Admin::ActivityLogs", type: :request do
  let(:admin) { create(:user, system_admin: true) }
  let(:regular_user) { create(:user) }

  def log_for(user:, action: "create", resource_type: "Pond", description: "Tanque X", event_type: nil)
    ActivityLog.record!(
      user: user, action: action, resource_type: resource_type,
      description: description, event_type: event_type, company: nil
    )
  end

  describe "GET /admin/activity_logs/:id (detalhamento)" do
    let(:company) { create(:company, name: "Piscicultura Azul") }
    let(:actor) { create(:user, name: "Maria Silva", email: "maria@example.com") }

    def detail_log(**attrs)
      ActivityLog.record!(**{
        user: actor, company: company, action: "update", resource_type: "Pond", resource_id: 42,
        description: "Tanque Norte", ip_address: "200.10.20.30",
        object_before: { "id" => 42, "name" => "Tanque A", "order_number" => 1, "updated_at" => "2026-09-25T10:00:00Z" },
        object_after: { "id" => 42, "name" => "Tanque B", "order_number" => 1, "updated_at" => "2026-09-25T11:00:00Z" }
      }.merge(attrs))
    end

    def located(place: "São Paulo, Brasil", isp: "Vivo")
      result = IpLocator::Result.new(ip_address: "200.10.20.30", kind: :found, place: place, city: "São Paulo", country: "Brasil", isp: isp)
      allow_any_instance_of(IpLocator).to receive(:locate).and_return(result)
    end

    before { sign_in admin }

    it "is denied to a non-admin and needs login" do
      log = detail_log
      sign_out admin

      get admin_activity_log_path(log)
      expect(response).to redirect_to(new_user_session_path)

      sign_in regular_user
      get admin_activity_log_path(log)
      expect(response).to redirect_to(root_path)
    end

    it "shows who, when, where, the record and the description" do
      located

      get admin_activity_log_path(detail_log)

      expect(response).to have_http_status(:ok)
      text = Nokogiri::HTML(response.body).text.gsub(/\s+/, " ")
      expect(text).to include("Detalhes da ação", "Atualização", "Tanque Norte", "Maria Silva", "maria@example.com", "Piscicultura Azul", "#42")
    end

    it "shows the IP and its approximate location" do
      located

      get admin_activity_log_path(detail_log)

      text = Nokogiri::HTML(response.body).at_css("[data-ip-location]").text.gsub(/\s+/, " ")
      expect(text).to include("200.10.20.30", "São Paulo, Brasil", "Provedor: Vivo", "Localização aproximada")
    end

    it "says the location is unavailable when the lookup fails, and shows the IP anyway" do
      allow_any_instance_of(IpLocator).to receive(:locate).and_return(nil)

      get admin_activity_log_path(detail_log)

      text = Nokogiri::HTML(response.body).at_css("[data-ip-location]").text.gsub(/\s+/, " ")
      expect(text).to include("200.10.20.30", "localização indisponível")
    end

    it "labels local addresses instead of looking them up" do
      get admin_activity_log_path(detail_log(ip_address: "127.0.0.1"))

      text = Nokogiri::HTML(response.body).at_css("[data-ip-location]").text.gsub(/\s+/, " ")
      expect(text).to include("127.0.0.1", "Rede local")
      expect(IpLocation.count).to eq(0)
    end

    it "handles a log without an IP" do
      get admin_activity_log_path(detail_log(ip_address: nil))

      expect(Nokogiri::HTML(response.body).at_css("[data-ip-location]").text).to include("IP não registrado")
    end

    it "lists only the fields that changed on an update, with before and after" do
      located

      get admin_activity_log_path(detail_log)

      doc = Nokogiri::HTML(response.body)
      expect(doc.text).to include("O que mudou")
      rows = doc.css("tbody tr").map { |tr| tr.css("td").map { |td| td.text.gsub(/\s+/, " ").strip } }
      expect(rows.size).to eq(1)
      expect(rows.first.first).to include("name")
      expect(rows.first[1]).to eq("Tanque A")
      expect(rows.first[2]).to eq("Tanque B")
    end

    it "shows the complete before and after JSON" do
      located

      get admin_activity_log_path(detail_log)

      pres = Nokogiri::HTML(response.body).css("turbo-frame#activity_log_detail details pre").map(&:text)
      expect(JSON.parse(pres.first)).to include("name" => "Tanque A")
      expect(JSON.parse(pres.last)).to include("name" => "Tanque B")
    end

    it "shows everything that was stored on a creation and everything removed on a destruction" do
      located
      created = detail_log(action: "create", object_before: nil, object_after: { "id" => 7, "name" => "Novo" })
      destroyed = detail_log(action: "destroy", object_before: { "id" => 7, "name" => "Velho" }, object_after: nil)

      get admin_activity_log_path(created)
      expect(response.body).to include("Dados gravados", "Não existia antes desta ação.")

      get admin_activity_log_path(destroyed)
      expect(response.body).to include("Dados removidos", "Não existe depois desta ação.")
    end

    it "explains that old logs have no detail" do
      located

      get admin_activity_log_path(detail_log(object_before: nil, object_after: nil))

      expect(response.body).to include("anterior à gravação do objeto antes e depois")
      expect(Nokogiri::HTML(response.body).css("turbo-frame#activity_log_detail details")).to be_empty
    end

    it "escapes what was stored, so a value can't inject markup" do
      located

      get admin_activity_log_path(detail_log(object_before: { "name" => "<img src=x onerror=alert(1)>" }, object_after: { "name" => "<script>alert(2)</script>" }))

      expect(response.body).not_to include("<img src=x")
      expect(response.body).not_to include("<script>alert(2)")
    end

    it "shows a fallback for a resource type that no longer exists" do
      located

      get admin_activity_log_path(detail_log(resource_type: "LegacyThing"))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LegacyThing")
    end

    it "answers a frame request with just the frame and a close button, without the layout" do
      located

      get admin_activity_log_path(detail_log), headers: { "Turbo-Frame" => "activity_log_detail" }

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#activity_log_detail")).to be_present
      expect(doc.at_css("button[data-action='click->dialog#close']")).to be_present
      expect(doc.css("nav")).to be_empty
    end

    it "renders as a normal page, with a way back, when opened directly" do
      located

      get admin_activity_log_path(detail_log)

      expect(response.body).to include("Voltar aos logs")
      expect(Nokogiri::HTML(response.body).at_css("button[data-action='click->dialog#close']")).to be_nil
    end
  end

  describe "opening the detail from the list" do
    before { sign_in admin }

    it "makes each row open the detail in the modal frame" do
      log = log_for(user: admin, description: "Criou o tanque Norte")

      get admin_activity_logs_path

      row = Nokogiri::HTML(response.body).at_css("tbody tr")
      expect(row["data-controller"]).to eq("row-link")
      link = row.at_css("a[data-row-link-target=link]")
      expect(link["href"]).to eq(admin_activity_log_path(log))
      expect(link["data-turbo-frame"]).to eq("activity_log_detail")
    end

    it "has the modal outside the list frame so it survives filters and paging" do
      get admin_activity_logs_path

      doc = Nokogiri::HTML(response.body)
      dialog = doc.at_css("dialog[data-controller=dialog]")
      expect(dialog).to be_present
      expect(dialog.at_css("turbo-frame#activity_log_detail")).to be_present
      expect(dialog.ancestors("turbo-frame")).to be_empty
    end
  end

  describe "Turbo Frame (only the list reloads)" do
    before { sign_in admin }

    it "wraps the filters, table and paging in a frame that advances the URL" do
      log_for(user: admin, description: "Criou o tanque Norte")

      get admin_activity_logs_path

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame#activity_logs")
      expect(frame["data-turbo-action"]).to eq("advance")
      expect(frame.at_css("select#user_id")).to be_present
      expect(frame.text).to include("Criou o tanque Norte")
      expect(Nokogiri::HTML(response.body).at_css("h1").ancestors("turbo-frame")).to be_empty
    end

    it "answers a frame request with just the filtered frame" do
      log_for(user: admin, description: "Criou o tanque Norte")
      log_for(user: admin, action: "destroy", description: "Removeu o tanque Sul")

      get admin_activity_logs_path(action_type: "destroy"), headers: { "Turbo-Frame" => "activity_logs" }

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("nav")).to be_empty
      expect(response.body).to include("Removeu o tanque Sul")
      expect(response.body).not_to include("Criou o tanque Norte")
    end
  end

  describe "GET /admin/activity_logs" do
    it "redirects to sign in when not authenticated" do
      get admin_activity_logs_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "denies access to a non-system-admin user" do
      sign_in regular_user

      get admin_activity_logs_path

      expect(response).to redirect_to(root_path)
    end

    it "lists activity logs for the system admin" do
      log_for(user: admin, description: "Criou o tanque Norte")
      sign_in admin

      get admin_activity_logs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Criou o tanque Norte")
    end

    it "filters by user_id" do
      mine = log_for(user: admin, description: "Log do admin")
      theirs = log_for(user: regular_user, description: "Log de outro")
      sign_in admin

      get admin_activity_logs_path, params: { user_id: admin.id }

      expect(response.body).to include(mine.description)
      expect(response.body).not_to include(theirs.description)
    end

    it "filters by action via the action_type param" do
      created = log_for(user: admin, action: "create", description: "Entrada criada")
      destroyed = log_for(user: admin, action: "destroy", description: "Entrada removida")
      sign_in admin

      get admin_activity_logs_path, params: { action_type: "destroy" }

      expect(response.body).to include(destroyed.description)
      expect(response.body).not_to include(created.description)
    end
  end
end
