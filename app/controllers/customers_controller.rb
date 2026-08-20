class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  SORTABLE_COLUMNS = {
    "name" => "name",
    "email" => "email"
  }.freeze

  def index
    @sort_column = SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : "name"
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    @customers = Customer.order(Arel.sql("#{SORTABLE_COLUMNS[@sort_column]} #{@sort_direction}"))
  end

  def show; end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      redirect_to customers_path, notice: "Cliente criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path, notice: "Cliente atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: "Cliente removido!"
  end

  private

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :address, :tax_id, :postal_code, :address_number, :address_complement, :neighborhood, :city, :state)
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end
end
