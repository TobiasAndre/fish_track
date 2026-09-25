class FeedingPlansController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: :share_pdf

  def index
    load_plan(plan_filters)

    respond_to do |format|
      format.html
      format.pdf { render_plan_pdf }
    end
  end

  # Cria o link público do PDF (para o WhatsApp) com os filtros atuais e volta
  # para a tela, que abre o WhatsApp com o link.
  def create_share
    filters = plan_filters.slice(:feeding_table_id, :unit_id, :batch_id, :pond_ids).compact_blank
    report_share = ReportShare.create!(report_type: "feeding_plan", filters: filters)

    redirect_to feeding_plans_path(filters.merge(report_share_id: report_share.id))
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @report_share = ReportShare.find_by!(id: params[:id], share_token: params[:share_token], report_type: "feeding_plan")
      load_plan(@report_share.filters.with_indifferent_access)

      respond_to do |format|
        format.pdf { render_plan_pdf }
      end
    end
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
      pond_ids: Array(params[:pond_ids]).compact_blank.presence
    ), notice: "Calibração salva."
  end

  private

  def plan_filters
    params.permit(:feeding_table_id, :unit_id, :batch_id, pond_ids: []).to_h.with_indifferent_access
  end

  def load_plan(filters)
    @feeding_tables = FeedingTable.order(:name)
    @feeding_table = @feeding_tables.find_by(id: filters[:feeding_table_id]) || @feeding_tables.first

    @units = Unit.order(:name)
    @selected_unit_id = filters[:unit_id].presence

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

    # Lote é opcional: sem ele, cada tanque soma os lotes ativos que tem.
    @selected_batch_id = filters[:batch_id].presence
    @selected_batch = @batches_for_select.find { |b| b.id.to_s == @selected_batch_id.to_s }

    @ponds_for_select =
      if @selected_unit_id.present?
        ponds = Pond.where(unit_id: @selected_unit_id)
        ponds = ponds.joins(:batch_stockings).where(batch_stockings: { batch_id: @selected_batch.id }) if @selected_batch
        ponds.ordered.distinct.to_a
      else
        []
      end

    # Tanques marcados reduzem a tabela; nenhum marcado = todos os tanques do filtro.
    requested_ids = Array(filters[:pond_ids]).map(&:to_s).compact_blank
    @selected_pond_ids = @ponds_for_select.map { |p| p.id.to_s } & requested_ids
    @ponds = @selected_pond_ids.any? ? @ponds_for_select.select { |p| @selected_pond_ids.include?(p.id.to_s) } : @ponds_for_select

    @plan = FeedingPlan.new(feeding_table: @feeding_table, ponds: @ponds, batch_id: @selected_batch&.id)
  end

  def render_plan_pdf
    @generated_at = Time.current

    render pdf: "arracoamento",
           template: "feeding_plans/index",
           layout: "pdf",
           encoding: "UTF-8",
           page_size: "A4",
           orientation: "Landscape",
           margin: { top: 10, bottom: 10, left: 8, right: 8 }
  end

  def calibration_params
    params.fetch(:calibrations, {}).permit!.to_h
  end
end
