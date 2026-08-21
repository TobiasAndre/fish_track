class LoadingEventsController < StockingEventPagesController
  skip_before_action :load_batch_stockings, only: %i[print share_pdf]
  skip_before_action :load_selected_batch_stocking, only: %i[print share_pdf]
  skip_before_action :load_current_avg_weight, only: %i[print share_pdf]
  skip_before_action :load_loading_form_collections, only: %i[print share_pdf]
  before_action :load_active_batch_stockings, only: [:index]

  def create
    @stocking_event = build_event_from_params

    if @stocking_event.save
      redirect_to loading_events_path(
        batch_stocking_id: @stocking_event.batch_stocking_id,
        printable_event_id: @stocking_event.id
      ), notice: success_message
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
      @events = filtered_events(@stocking_event.batch_stocking_id)
      load_active_batch_stockings

      render :index, status: :unprocessable_content
    end
  end

  def edit
    @stocking_event = StockingEvent.find(params[:id])
    @selected_batch_stocking = @stocking_event.batch_stocking
    @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
    @events = filtered_events(@stocking_event.batch_stocking_id)

    render :index
  end

  def update
    @stocking_event = StockingEvent.find(params[:id])
    @stocking_event.assign_attributes(event_params)

    if @stocking_event.save
      redirect_to loading_events_path(batch_stocking_id: @stocking_event.batch_stocking_id),
        notice: "Carregamento atualizado com sucesso."
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @current_avg_weight_g = current_avg_weight_for(@selected_batch_stocking)
      @events = filtered_events(@stocking_event.batch_stocking_id)
      load_active_batch_stockings

      render :index, status: :unprocessable_content
    end
  end

  def print
    @stocking_event = StockingEvent.find(params[:id])

    respond_to do |format|
      format.html

      format.pdf do
        html = render_to_string(
          template: "loading_events/print",
          layout: "pdf",
          formats: [:html]
        )

        pdf = WickedPdf.new.pdf_from_string(
          html,
          page_size: "A4",
          encoding: "UTF-8",
          margin: { top: 10, bottom: 10, left: 10, right: 10 }
        )

        send_data pdf,
                  filename: "carregamento-#{@stocking_event.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @stocking_event = StockingEvent.find_by!(
        id: params[:id],
        share_token: params[:share_token]
      )

      respond_to do |format|
        format.pdf do
          render pdf: "carregamento-#{@stocking_event.id}",
                template: "loading_events/print",
                layout: "pdf",
                formats: [:html],
                encoding: "UTF-8",
                page_size: "A4"
        end
      end
    end
  end

  private

  def event_type
    "loading"
  end

  def redirect_path_for(batch_stocking_id)
    loading_events_path(batch_stocking_id:)
  end

  def success_message
    "Carregamento lançado com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :quantity,
      :avg_weight_g,
      :total_weight_kg,
      :notes,
      :customer_id,
      :integrated_id,
      :supplier_id,
      :payment_date,
      :price_per_kg_cents,
      :thousand_value_cents,
      :freight_cost_cents,
      :loading_cost_cents,
      :payment_method_id,
      :tax_percentage,
      :loading_destination,
      :gta_number,
      :invoice_number
    )
  end

  def load_active_batch_stockings
    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence
    @ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id).order(:name) : Pond.order(:name)
    @selected_pond_id = params[:pond_id].presence
    @selected_pond_id = nil if @selected_pond_id.present? && !@ponds.exists?(id: @selected_pond_id)

    @active_batch_stockings =
      BatchStocking
        .includes(:batch, :pond, :loading_events)
        .joins(:batch, :pond)
        .where(batches: { status: "active" })

    @active_batch_stockings = @active_batch_stockings.where(ponds: { unit_id: @selected_unit_id }) if @selected_unit_id.present?
    @active_batch_stockings = @active_batch_stockings.where(pond_id: @selected_pond_id) if @selected_pond_id.present?

    @active_batch_stockings = @active_batch_stockings.order("batches.name ASC", "batch_stockings.stocked_on DESC")
  end
end
