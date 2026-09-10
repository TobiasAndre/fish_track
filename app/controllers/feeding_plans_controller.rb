class FeedingPlansController < ApplicationController
  before_action :authenticate_user!

  def index
    @feeding_tables = FeedingTable.order(:name)
    @feeding_table = @feeding_tables.find_by(id: params[:feeding_table_id]) || @feeding_tables.first

    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence

    ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id) : Pond.all
    @ponds = ponds.includes(:unit).ordered.to_a

    @plan = FeedingPlan.new(feeding_table: @feeding_table, ponds: @ponds)
  end

  def calibrations
    calibration_params.each do |pond_id, attrs|
      pond = Pond.find_by(id: pond_id)
      next unless pond

      pond.update(
        feed_sample_kg: attrs[:feed_sample_kg].presence,
        feed_sample_seconds: attrs[:feed_sample_seconds].presence
      )
    end

    redirect_to feeding_plans_path(
      feeding_table_id: params[:feeding_table_id].presence,
      unit_id: params[:unit_id].presence
    ), notice: "Calibração salva."
  end

  private

  def calibration_params
    params.fetch(:calibrations, {}).permit!.to_h
  end
end
