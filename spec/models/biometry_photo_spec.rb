require "rails_helper"

RSpec.describe BiometryPhoto, type: :model do
  let(:batch) { create(:batch, stocking_quantity: 1000, stocking_avg_weight_g: 5.0) }
  let(:event) { create(:stocking_event, :biometrics, batch_stocking: batch.batch_stockings.first) }

  def upload(name = "peixe.jpg", type = "image/jpeg")
    Rack::Test::UploadedFile.new(file_fixture(name), type)
  end

  it "stores the file and records where it is" do
    photo = described_class.attach!(event, upload)

    expect(photo).to have_attributes(stocking_event: event, content_type: "image/jpeg", filename: "peixe.jpg")
    expect(photo.blob_object_id).to start_with("local/fishtrack/")
    expect(photo.url).to start_with("/dev_uploads/fishtrack/")
    expect(Rails.root.join("tmp/test_uploads", photo.blob_object_id.delete_prefix("local/"))).to exist
  end

  it "checks the real content, not the extension" do
    expect { described_class.attach!(event, upload("nao_e_foto.jpg")) }.to raise_error(BiometryPhoto::Error, /não é uma imagem/)
    expect(described_class.count).to eq(0)
  end

  it "accepts at most #{BiometryPhoto::MAX_PER_EVENT} photos per biometry" do
    BiometryPhoto::MAX_PER_EVENT.times { described_class.attach!(event, upload) }

    expect { described_class.attach!(event, upload) }.to raise_error(BiometryPhoto::Error, /até #{BiometryPhoto::MAX_PER_EVENT} fotos/)
  end

  it "turns a storage failure into a message for the user" do
    storage = instance_double(PhotoStorage::Local)
    allow(storage).to receive(:upload).and_raise(PhotoStorage::Error, "Falha ao guardar a foto: o espaço do Blob da Square Cloud acabou.")
    allow(PhotoStorage).to receive(:current).and_return(storage)

    expect { described_class.attach!(event, upload) }.to raise_error(BiometryPhoto::Error, /espaço do Blob/)
    expect(described_class.count).to eq(0)
  end

  it "deletes the stored file when the photo or the biometry is removed" do
    photo = described_class.attach!(event, upload)
    path = Rails.root.join("tmp/test_uploads", photo.blob_object_id.delete_prefix("local/"))

    event.destroy!

    expect(described_class.exists?(photo.id)).to be(false)
    expect(path).not_to exist
  end
end
