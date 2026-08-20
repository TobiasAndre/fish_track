class SuppliersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_supplier, only: [:show, :edit, :update, :destroy]

  SORTABLE_COLUMNS = {
    "name" => "name",
    "email" => "email"
  }.freeze

  def index
    @sort_column = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "name"
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"

    @suppliers = Supplier
      .order(Arel.sql("#{SORTABLE_COLUMNS[@sort_column]} #{@sort_direction}"))
      .page(params[:page])
      .per(10)
  end

  def show; end

  def new
    @supplier = Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)
    if @supplier.save
      redirect_to suppliers_path, notice: "Fornecedor criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @supplier.update(supplier_params)
      redirect_to suppliers_path, notice: "Fornecedor atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @supplier.destroy!
    redirect_to suppliers_path, notice: "Fornecedor removido!"
  end

  private

  def supplier_params
    params.require(:supplier).permit(:name, :tax_id, :email, :state_registration,
                                     :address, :postal_code, :city, :state)
  end

  def set_supplier
    @supplier = Supplier.find(params[:id])
  end
end
