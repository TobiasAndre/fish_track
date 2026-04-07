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
      :notes
    )
  end
end
