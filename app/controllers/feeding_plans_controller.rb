class FeedingPlansController < ApplicationController
  before_action :authenticate_user!

  def index
    @feeding_tables = FeedingTable.order(:name)
    @feeding_table = @feeding_tables.find_by(id: params[:feeding_table_id]) || @feeding_tables.first

    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence

    @batches_for_select =
      if @selected_unit_id.present?
        Batch
          .joins(batch_stockings: :pond)
          .where(status: "active", ponds: { unit_id: @selected_unit_id })
          .distinct
          .order(:name)
          .to_a
      else
        []
      end

    @selected_batch_id = params[:batch_id].presence
    @selected_batch = @batches_for_select.find { |b| b.id.to_s == @selected_batch_id }

    @ponds_for_select =
      if @selected_batch
        Pond
          .joins(:batch_stockings)
          .where(unit_id: @selected_unit_id, batch_stockings: { batch_id: @selected_batch.id })
          .ordered
          .distinct
          .to_a
      else
        []
      end

    @selected_pond_id = params[:pond_id].presence
    @selected_pond = @ponds_for_select.find { |p| p.id.to_s == @selected_pond_id }

    @ponds = @selected_pond ? [@selected_pond] : []

    @plan = FeedingPlan.new(feeding_table: @feeding_table, ponds: @ponds, batch_id: @selected_batch&.id)
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
      unit_id: params[:unit_id].presence,
      batch_id: params[:batch_id].presence,
      pond_id: params[:pond_id].presence
    ), notice: "Calibração salva."
  end

  private

  def calibration_params
    params.fetch(:calibrations, {}).permit!.to_h
  end
end
