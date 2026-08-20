require "rails_helper"

RSpec.describe "Suppliers", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /suppliers" do
    it "redirects to sign in when not authenticated" do
      sign_out user

      get suppliers_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists suppliers" do
      supplier = create(:supplier)

      get suppliers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(supplier.name)
    end

    it "sorts by name ascending by default" do
      z = create(:supplier, name: "Zulu")
      a = create(:supplier, name: "Alfa")

      get suppliers_path

      expect(response.body.index(a.name)).to be < response.body.index(z.name)
    end

    it "sorts by the given column and direction" do
      b = create(:supplier, name: "Fornecedor B", email: "bravo@example.com")
      a = create(:supplier, name: "Fornecedor A", email: "alfa@example.com")

      get suppliers_path, params: { sort: "email", direction: "desc" }

      expect(response.body.index(b.name)).to be < response.body.index(a.name)
    end

    it "ignores an unknown sort column instead of raising" do
      create(:supplier, name: "Qualquer")

      get suppliers_path, params: { sort: "not_a_real_column" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /suppliers" do
    it "creates a supplier with valid params" do
      expect do
        post suppliers_path, params: { supplier: { name: "Fornecedor A" } }
      end.to change(Supplier, :count).by(1)

      expect(response).to redirect_to(suppliers_path)
    end

    it "does not create a supplier without a name" do
      expect do
        post suppliers_path, params: { supplier: { name: "" } }
      end.not_to change(Supplier, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /suppliers/:id" do
    it "updates the supplier" do
      supplier = create(:supplier, name: "Old name")

      patch supplier_path(supplier), params: { supplier: { name: "New name" } }

      expect(response).to redirect_to(suppliers_path)
      expect(supplier.reload.name).to eq("New name")
    end
  end

  describe "DELETE /suppliers/:id" do
    it "removes the supplier" do
      supplier = create(:supplier)

      expect do
        delete supplier_path(supplier)
      end.to change(Supplier, :count).by(-1)

      expect(response).to redirect_to(suppliers_path)
    end
  end
end
