class MortalityEventsController < StockingEventPagesController
  private

  def event_type
    "mortality"
  end

  def redirect_path_for(batch_stocking_id)
    mortality_events_path(batch_stocking_id:)
  end

  def success_message
    "Mortalidade lançada com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :quantity,
      :notes
    )
  end
end
