require "rails_helper"

RSpec.describe "Batches", type: :request do
  let(:user) { create(:user) }
  let(:unit) { create(:unit) }
  let(:pond) { create(:pond, unit: unit) }

  before { sign_in user }

  describe "GET /batches" do
    it "lists batches" do
      batch = create(:batch, pond: pond, name: "Lote Verão")

      get batches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lote Verão")
    end
  end

  describe "GET /batches/:id" do
    it "shows the batch" do
      batch = create(:batch, pond: pond, name: "Lote Verão")

      get batch_path(batch)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /batches" do
    it "creates a batch with a nested batch stocking" do
      expect do
        post batches_path, params: {
          batch: {
            name: "Novo lote",
            status: "active",
            stage: "juvenile",
            started_on: Date.current,
            batch_stockings_attributes: {
              "0" => {
                pond_id: pond.id,
                quantity: 1000,
                avg_weight_g: 5.0,
                stocked_on: Date.current
              }
            }
          }
        }
      end.to change(Batch, :count).by(1)

      expect(response).to redirect_to(batches_path)
    end

    it "does not create a batch without any batch stocking" do
      expect do
        post batches_path, params: {
          batch: {
            name: "Sem lote",
            status: "active",
            stage: "juvenile",
            started_on: Date.current,
            batch_stockings_attributes: {}
          }
        }
      end.not_to change(Batch, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /batches/:id" do
    it "updates the batch" do
      batch = create(:batch, pond: pond, name: "Old name")

      patch batch_path(batch), params: { batch: { name: "New name" } }

      expect(response).to redirect_to(batches_path)
      expect(batch.reload.name).to eq("New name")
    end
  end

  describe "DELETE /batches/:id" do
    it "removes the batch" do
      batch = create(:batch, pond: pond)

      expect do
        delete batch_path(batch)
      end.to change(Batch, :count).by(-1)

      expect(response).to redirect_to(batches_path)
    end
  end
end
