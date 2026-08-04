class LoadingEventsController < StockingEventPagesController
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
end
