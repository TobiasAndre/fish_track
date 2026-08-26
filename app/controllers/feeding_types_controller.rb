class FeedingTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_feeding_type, only: [:edit, :update, :destroy]
  before_action :load_feeding_brands, only: [:new, :create, :edit, :update]

  def index
    @feeding_types = FeedingType.includes(:feeding_brand).order(:name)
  end

  def new
    @feeding_type = FeedingType.new
  end

  def create
    @feeding_type = FeedingType.new(feeding_type_params)

    if @feeding_type.save
      redirect_to feeding_types_path, notice: "Tipo de ração criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @feeding_type.update(feeding_type_params)
      redirect_to feeding_types_path, notice: "Tipo de ração atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @feeding_type.destroy
      redirect_to feeding_types_path, notice: "Tipo de ração removido!"
    else
      redirect_to feeding_types_path, alert: @feeding_type.errors.full_messages.to_sentence
    end
  end

  private

  def set_feeding_type
    @feeding_type = FeedingType.find(params[:id])
  end

  def load_feeding_brands
    @feeding_brands = FeedingBrand.order(:name)
  end

  def feeding_type_params
    params.require(:feeding_type).permit(:name, :feeding_brand_id)
  end
end
