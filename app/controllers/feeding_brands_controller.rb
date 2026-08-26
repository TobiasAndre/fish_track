class FeedingBrandsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_feeding_brand, only: [:edit, :update, :destroy]

  def index
    @feeding_brands = FeedingBrand.order(:name)
  end

  def new
    @feeding_brand = FeedingBrand.new
  end

  def create
    @feeding_brand = FeedingBrand.new(feeding_brand_params)

    if @feeding_brand.save
      redirect_to feeding_brands_path, notice: "Marca de ração criada!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @feeding_brand.update(feeding_brand_params)
      redirect_to feeding_brands_path, notice: "Marca de ração atualizada!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @feeding_brand.destroy
      redirect_to feeding_brands_path, notice: "Marca de ração removida!"
    else
      redirect_to feeding_brands_path, alert: @feeding_brand.errors.full_messages.to_sentence
    end
  end

  private

  def set_feeding_brand
    @feeding_brand = FeedingBrand.find(params[:id])
  end

  def feeding_brand_params
    params.require(:feeding_brand).permit(:name)
  end
end
