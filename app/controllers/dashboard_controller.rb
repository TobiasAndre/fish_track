class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    company = current_user.company
    redirect_to new_company_path, alert: "Crie sua empresa primeiro." and return if company.blank?

    @active_batches_count = company.batches.where(status: "active").count
    @active_ponds_count   = company.ponds.count

    # soma de quantidade atual dos lotes ativos (ignora nil)
    @total_current_quantity = company.batches.where(status: "active").sum("COALESCE(current_quantity, 0)")

    # últimos eventos (em todos os lotes)
    @recent_events = company.batch_events
                            .includes(batch: { pond: :unit })
                            .order(occurred_on: :desc, created_at: :desc)
                            .limit(5)

    # lotes ativos para cards
    @active_batches = company.batches
                             .where(status: "active")
                             .includes(pond: :unit)
                             .order(started_on: :desc)
                             .limit(5)
  end
end
