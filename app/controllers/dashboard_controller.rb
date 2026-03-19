class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    if session[:tenant_name].blank? || Apartment::Tenant.current == "public"
      redirect_to new_user_session_path, alert: "Selecione uma empresa para continuar."
      return
    end

    @active_batches_count = Batch.where(status: "active").count
    @active_ponds_count   = Pond.count

    @total_current_quantity = Batch.where(status: "active").sum("COALESCE(current_quantity, 0)")

    @recent_events = BatchEvent
      .includes(batch: { ponds: :unit })
      .order(occurred_on: :desc, created_at: :desc)
      .limit(5)

    @active_batches = Batch
      .where(status: "active")
      .includes(ponds: :unit)
      .order(started_on: :desc)
      .limit(5)
  end
end
