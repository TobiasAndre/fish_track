class DashboardController < ApplicationController
  before_action :authenticate_user!

  PAYABLES_LIMIT = 10

  def show
    if session[:tenant_name].blank? || Apartment::Tenant.current == "public"
      redirect_to user_signed_in? ? select_company_path : new_user_session_path,
        alert: "Selecione uma empresa para continuar."
      return
    end

    active_batches = Batch.where(status: "active")
    @active_batches_count = active_batches.count

    @figures = DashboardFigures.new(active_batches.to_a)

    @active_batches = active_batches
      .includes(batch_stockings: [{ pond: :unit }, :stocking_events])
      .order(started_on: :desc)
      .limit(5)

    # O que falta pagar / receber (saldo em aberto), do vencimento mais próximo ao mais distante.
    @payables = open_entries(FinancialEntry.payable)
    @receivables = open_entries(FinancialEntry.receivable)
    @payables_total_cents = FinancialEntry.pending.payable.open_balance_cents
    @receivables_total_cents = FinancialEntry.pending.receivable.open_balance_cents
    @payables_count = FinancialEntry.pending.payable.count
    @receivables_count = FinancialEntry.pending.receivable.count
  end

  private

  def open_entries(scope)
    scope.pending.order(:due_on, :id).limit(PAYABLES_LIMIT).to_a
  end
end
