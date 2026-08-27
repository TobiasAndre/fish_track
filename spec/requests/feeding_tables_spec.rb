require "rails_helper"

RSpec.describe "FeedingTables", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /feeding_tables" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get feeding_tables_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists feeding tables" do
      table = create(:feeding_table, name: "Tabela padrão")

      get feeding_tables_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tabela padrão")
    end
  end

  describe "POST /feeding_tables" do
    it "creates a feeding table and redirects to fill in percentages" do
      expect do
        post feeding_tables_path, params: { feeding_table: { name: "Nova tabela" } }
      end.to change(FeedingTable, :count).by(1)

      expect(response).to redirect_to(edit_feeding_table_path(FeedingTable.last))
    end

    it "does not create a feeding table without a name" do
      expect do
        post feeding_tables_path, params: { feeding_table: { name: "" } }
      end.not_to change(FeedingTable, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /feeding_tables/:id/edit" do
    it "shows the strategy matrix" do
      table = create(:feeding_table)

      get edit_feeding_table_path(table)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /feeding_tables/:id" do
    it "updates the feeding table" do
      table = create(:feeding_table, name: "Old name")

      patch feeding_table_path(table), params: { feeding_table: { name: "New name" } }

      expect(response).to redirect_to(edit_feeding_table_path(table))
      expect(table.reload.name).to eq("New name")
    end
  end

  describe "DELETE /feeding_tables/:id" do
    it "removes the feeding table" do
      table = create(:feeding_table)

      expect do
        delete feeding_table_path(table)
      end.to change(FeedingTable, :count).by(-1)

      expect(response).to redirect_to(feeding_tables_path)
    end
  end

  describe "GET /feeding_tables/:id/print.pdf" do
    it "returns a PDF" do
      table = create(:feeding_table)

      get print_feeding_table_path(table, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end
  end

  describe "GET /shared/:tenant_name/feeding_tables/:id/:share_token" do
    it "renders the PDF publicly, without requiring authentication" do
      sign_out user
      table = create(:feeding_table)

      get shared_feeding_table_pdf_path(tenant_name: "public", id: table.id, share_token: table.share_token, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
    end

    it "is not found with an invalid share_token" do
      table = create(:feeding_table)

      get shared_feeding_table_pdf_path(tenant_name: "public", id: table.id, share_token: "wrong-token", format: :pdf)

      expect(response).to have_http_status(:not_found)
    end
  end
end
