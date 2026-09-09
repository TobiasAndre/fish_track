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

  describe "GET /batches/:id/edit" do
    it "renders the add-stocking template with a properly namespaced quantity field" do
      batch = create(:batch, pond: pond)

      get edit_batch_path(batch)

      expect(response).to have_http_status(:ok)
      # The "Adicionar" template must namespace every field under
      # batch_stockings_attributes -- a bare batch[quantity] would be dropped
      # by strong params and leave the new stocking without a quantity.
      expect(response.body).to include('name="batch[batch_stockings_attributes][NEW_RECORD][quantity]"')
      expect(response.body).not_to include('name="batch[quantity]"')
    end
  end

  describe "PATCH /batches/:id" do
    it "updates the batch" do
      batch = create(:batch, pond: pond, name: "Old name")

      patch batch_path(batch), params: { batch: { name: "New name" } }

      expect(response).to redirect_to(batches_path)
      expect(batch.reload.name).to eq("New name")
    end

    it "adds a new batch stocking to an existing batch" do
      batch = create(:batch, pond: pond, stocking_quantity: 1000, stocking_avg_weight_g: 5.0)
      other_pond = create(:pond, unit: unit)
      existing = batch.batch_stockings.first

      expect do
        patch batch_path(batch), params: {
          batch: {
            batch_stockings_attributes: {
              "0" => { id: existing.id, pond_id: existing.pond_id, quantity: existing.quantity,
                       avg_weight_g: existing.avg_weight_g, stocked_on: existing.stocked_on },
              "1710000000000" => { pond_id: other_pond.id, quantity: "2.000",
                                   avg_weight_g: 4.0, stocked_on: Date.current }
            }
          }
        }
      end.to change { batch.batch_stockings.count }.from(1).to(2)

      expect(response).to redirect_to(batches_path)
      expect(batch.batch_stockings.find_by(pond_id: other_pond.id).quantity).to eq(2000)
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
