require "rails_helper"

RSpec.describe "Biometry photos", type: :request do
  let(:user) { create(:user, system_admin: true) }
  let(:batch) { create(:batch, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let!(:batch_stocking) { batch.batch_stockings.first }

  def photo(name = "peixe.jpg")
    Rack::Test::UploadedFile.new(file_fixture(name), "image/jpeg")
  end

  def biometry_params
    { batch_stocking_id: batch_stocking.id, occurred_on: Date.current, volume: "1000", quantity: "50", total_weight_kg: "10" }
  end

  describe "regular form" do
    before { sign_in user }

    it "saves the photos chosen when launching a biometry" do
      expect do
        post biometry_events_path, params: { stocking_event: biometry_params, photos: [photo, photo] }
      end.to change(BiometryPhoto, :count).by(2)

      event = StockingEvent.where(event_type: "biometrics").order(:id).last
      expect(event.biometry_photos.size).to eq(2)
      expect(flash[:alert]).to be_blank
    end

    it "adds photos when editing and lists the saved ones with a remove action" do
      event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking)
      BiometryPhoto.attach!(event, photo)

      patch biometry_event_path(event), params: { stocking_event: biometry_params, photos: [photo] }
      expect(event.biometry_photos.count).to eq(2)

      get edit_biometry_event_path(event)
      page = Nokogiri::HTML(response.body)
      expect(page.css("img[alt='Foto da biometria']").size).to eq(2)
      expect(page.css("a[data-turbo-method='delete'][href^='/biometry_events/#{event.id}/photos/']").size).to eq(2)
      expect(page.at_css("form[enctype='multipart/form-data'] input[type='file'][name='photos[]'][multiple]")).to be_present
    end

    it "keeps the biometry when a photo cannot be stored, and says which and why" do
      allow(BiometryPhoto).to receive(:attach!).and_raise(BiometryPhoto::Error, "o espaço do Blob da Square Cloud acabou")

      expect do
        post biometry_events_path, params: { stocking_event: biometry_params, photos: [photo] }
      end.to change { StockingEvent.where(event_type: "biometrics").count }.by(1)

      expect(flash[:notice]).to eq("Biometria lançada com sucesso.")
      expect(flash[:alert]).to eq("1 foto(s) não foram guardadas: o espaço do Blob da Square Cloud acabou.")
    end

    it "removes a photo" do
      event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking)
      kept = BiometryPhoto.attach!(event, photo)
      removed = BiometryPhoto.attach!(event, photo)

      delete biometry_event_photo_path(event, removed)

      expect(response).to redirect_to(edit_biometry_event_path(event))
      expect(event.biometry_photos.reload).to eq([kept])
    end

    describe "gallery" do
      def gallery_buttons
        Nokogiri::HTML(response.body).css("button[data-action='photo-gallery#open']")
      end

      it "puts a photos button before the edit action of a biometry with photos, in the batch history" do
        with_photos = create(:stocking_event, :biometrics, batch_stocking: batch_stocking, occurred_on: Date.new(2026, 10, 1))
        first = BiometryPhoto.attach!(with_photos, photo)
        second = BiometryPhoto.attach!(with_photos, photo)
        create(:stocking_event, :biometrics, batch_stocking: batch_stocking, occurred_on: Date.new(2026, 10, 2))

        get biometry_events_path(batch_stocking_id: batch_stocking.id)

        expect(gallery_buttons.size).to eq(1)
        button = gallery_buttons.first
        expect(JSON.parse(button["data-photo-gallery-photos-param"])).to eq([first.url, second.url])
        expect(button["data-photo-gallery-title-param"]).to eq("Biometria de 01/10/2026")
        expect(button["title"]).to eq("Ver fotos (2)")
        expect(button.next_element["title"]).to eq("Editar")
        expect(Nokogiri::HTML(response.body).at_css("[data-controller~='photo-gallery'] dialog[data-photo-gallery-target='dialog']")).to be_present
      end

      it "also offers it in the overview of active batches" do
        event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking)
        BiometryPhoto.attach!(event, photo)

        get biometry_events_path

        expect(gallery_buttons.size).to eq(1)
      end
    end

    it "shows the photos under each biometry in the history" do
      event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking)
      stored = BiometryPhoto.attach!(event, photo)

      get biometry_events_path(batch_stocking_id: batch_stocking.id)

      thumbnail = Nokogiri::HTML(response.body).at_css("td[colspan='11'] img")
      expect(thumbnail["src"]).to eq(stored.url)
    end
  end

  it "does not let a read-only profile remove photos" do
    company = create(:company, tenant_name: "public")
    profile = create(:access_profile, permission_matrix: { "dashboard" => %w[read], "biometry_events" => %w[read], "__submitted" => "1" })
    member = create(:user)
    create(:membership, user: member, company: company, role: "member", access_profile_id: profile.id)
    post user_session_path, params: { user: { tenant_name: "public", email: member.email, password: "password123" } }
    event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking)
    stored = BiometryPhoto.attach!(event, photo)

    delete biometry_event_photo_path(event, stored)

    expect(BiometryPhoto.exists?(stored.id)).to be(true)
  end

  describe "photos sent by the field (offline) screen" do
    let(:company) { create(:company, tenant_name: "public") }
    let(:field_user) { create(:user) }
    let(:entry_uuid) { SecureRandom.uuid }

    before do
      create(:membership, user: field_user, company: company, role: "owner")
      post user_session_path, params: { user: { tenant_name: "public", email: field_user.email, password: "password123" } }
    end

    def send_photo(photo_uuid: SecureRandom.uuid, file: photo)
      post sync_photo_biometry_events_path, params: { entry_uuid: entry_uuid, photo_uuid: photo_uuid, photo: file },
        headers: { "Accept" => "application/json" }
    end

    it "waits for the biometry itself to arrive first" do
      send_photo

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].first).to include("ainda não foi enviada")
    end

    it "attaches the photo to the biometry of the same device entry, once" do
      event = create(:stocking_event, :biometrics, batch_stocking: batch_stocking, client_uuid: entry_uuid)
      photo_uuid = SecureRandom.uuid

      send_photo(photo_uuid: photo_uuid)
      expect(response.parsed_body).to include("status" => "created")

      expect { send_photo(photo_uuid: photo_uuid) }.not_to change(BiometryPhoto, :count)
      expect(response.parsed_body).to include("status" => "duplicate")
      expect(event.biometry_photos.pluck(:client_uuid)).to eq([photo_uuid])
    end

    it "reports a file that is not an image" do
      create(:stocking_event, :biometrics, batch_stocking: batch_stocking, client_uuid: entry_uuid)

      send_photo(file: Rack::Test::UploadedFile.new(file_fixture("nao_e_foto.jpg"), "image/jpeg"))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].first).to include("não é uma imagem")
    end
  end
end
