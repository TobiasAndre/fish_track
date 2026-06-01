class FeedingTablesController < ApplicationController
  before_action :set_feeding_table, only: %i[edit update destroy]
  before_action :load_ranges, only: %i[edit update]

  def index
    @feeding_tables =
      FeedingTable
        .includes(:feeding_strategy_items)
        .order(:name)

    @weight_ranges_count = FeedingWeightRange.count
    @temperature_ranges_count = FeedingTemperatureRange.count
  end

  def new
    @feeding_table = FeedingTable.new
  end

  def create
    @feeding_table = FeedingTable.new(feeding_table_params)

    if @feeding_table.save
      redirect_to edit_feeding_table_path(@feeding_table), notice: "Tabela criada. Agora preencha os percentuais."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @feeding_strategy_item = @feeding_table.feeding_strategy_items.build
    build_matrix
  end

  def update
    if @feeding_table.update(feeding_table_params)
      redirect_to edit_feeding_table_path(@feeding_table), notice: "Tabela atualizada com sucesso."
    else
      @feeding_strategy_item = @feeding_table.feeding_strategy_items.build
      build_matrix
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feeding_table.destroy
    redirect_to feeding_tables_path, notice: "Tabela removida com sucesso."
  end

  def print
    @feeding_table = FeedingTable.find(params[:id])

    @weight_ranges =
      FeedingWeightRange.order(:weight_from)

    @temperature_ranges =
      FeedingTemperatureRange.order(:temperature_from)

    @strategy_matrix =
      @feeding_table
        .feeding_strategy_items
        .index_by do |item|
          [
            item.feeding_weight_range_id,
            item.feeding_temperature_range_id
          ]
        end

    render layout: false
  end

  private

  def set_feeding_table
    @feeding_table = FeedingTable.find(params[:id])
  end

  def load_ranges
    @weight_ranges = FeedingWeightRange.order(:weight_from)
    @temperature_ranges = FeedingTemperatureRange.order(:temperature_from)
  end

  def build_matrix
    @strategy_items =
      @feeding_table
        .feeding_strategy_items
        .includes(:feeding_weight_range, :feeding_temperature_range)

    @strategy_matrix = @strategy_items.index_by do |item|
      [item.feeding_weight_range_id, item.feeding_temperature_range_id]
    end
  end

  def feeding_table_params
    params.require(:feeding_table).permit(:name, :description)
  end
end