class FeedingStrategyItemsController < ApplicationController
  before_action :set_feeding_table

  def create
    @feeding_strategy_item =
      @feeding_table.feeding_strategy_items.find_or_initialize_by(
        feeding_weight_range_id: strategy_item_params[:feeding_weight_range_id],
        feeding_temperature_range_id: strategy_item_params[:feeding_temperature_range_id]
      )

    @feeding_strategy_item.feeding_percentage =
      strategy_item_params[:feeding_percentage]

    if @feeding_strategy_item.save
      redirect_to edit_feeding_table_path(@feeding_table),
                  notice: "Percentual salvo com sucesso."
    else
      redirect_to edit_feeding_table_path(@feeding_table),
                  alert: @feeding_strategy_item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = @feeding_table.feeding_strategy_items.find(params[:id])
    item.destroy

    redirect_to edit_feeding_table_path(@feeding_table),
                notice: "Percentual removido."
  end

  private

  def set_feeding_table
    @feeding_table = FeedingTable.find(params[:feeding_table_id])
  end

  def strategy_item_params
    params.require(:feeding_strategy_item).permit(
      :feeding_weight_range_id,
      :feeding_temperature_range_id,
      :feeding_percentage
    )
  end
end