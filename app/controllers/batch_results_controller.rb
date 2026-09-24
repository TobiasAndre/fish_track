class BatchResultsController < ApplicationController
  before_action :authenticate_user!

  def index
    @q_status = params[:status].presence_in(BatchResult::STATUSES)
    @q_from = params[:from].presence
    @q_to = params[:to].presence

    @result = BatchResult.new(status: @q_status, from: @q_from, to: @q_to)

    respond_to do |format|
      format.html
      format.pdf do
        @generated_at = Time.current
        render pdf: "resultado-por-lote",
               template: "batch_results/index",
               layout: "pdf",
               encoding: "UTF-8",
               page_size: "A4",
               orientation: "Landscape",
               margin: { top: 10, bottom: 10, left: 8, right: 8 }
      end
    end
  end
end
