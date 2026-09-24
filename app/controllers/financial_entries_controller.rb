class FinancialEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entry, only: [:edit, :update, :destroy, :settle, :unsettle]

  PER_PAGE_OPTIONS = [10, 20, 30, 50].freeze
  STATUS_OPTIONS = %w[pending partial settled overdue].freeze

  def index
    @q_stage = params[:stage].presence
    @q_from  = params[:from].presence
    @q_to    = params[:to].presence
    @q_type  = params[:entry_type].presence
    @q_batch_id = params[:batch_id].presence
    @q_status = params[:status].presence_in(STATUS_OPTIONS)
    @per_page = per_page
    @per_page_options = PER_PAGE_OPTIONS

    @batches = Batch.order(:status, started_on: :desc)

    base = FinancialEntry.includes(:unit, :batch)
    base = base.where(stage: @q_stage) if @q_stage.present?
    base = base.where(entry_type: @q_type) if @q_type.present?
    base = base.where(batch_id: @q_batch_id) if @q_batch_id.present?
    base = base.where("occurred_on >= ?", @q_from) if @q_from.present?
    base = base.where("occurred_on <= ?", @q_to) if @q_to.present?

    scope =
      case @q_status
      when "pending" then base.pending
      when "partial" then base.partially_paid
      when "settled" then base.settled
      when "overdue" then base.overdue
      else base
      end

    ordered = scope.order(due_on: :desc, occurred_on: :desc, created_at: :desc)

    # Totais do recorte atual (respeitam os filtros, menos a paginação).
    @total_income_cents  = scope.income.sum(:amount_cents)
    @total_expense_cents = scope.expense.sum(:amount_cents)
    @balance_cents       = @total_income_cents - @total_expense_cents

    # Contas em aberto / vencidas — ignoram o filtro de situação para dar a
    # visão de fluxo futuro dentro dos demais filtros.
    # (saldo em aberto: o que já foi pago parcialmente não conta como devido)
    @pending_payable_cents    = base.pending.payable.open_balance_cents
    @pending_receivable_cents = base.pending.receivable.open_balance_cents
    @overdue_cents            = base.overdue.open_balance_cents
    @overdue_count            = base.overdue.count

    respond_to do |format|
      format.html { @entries = ordered.page(params[:page]).per(@per_page) }
      format.pdf do
        @entries = ordered
        @generated_at = Time.current
        render_financial_report_pdf
      end
    end
  end

  def new
    @entry = FinancialEntry.new(
      entry_type: "expense",
      stage: "general",
      occurred_on: Date.current
    )
  end

  def create
    @entry = FinancialEntry.new(financial_entry_params)

    if @entry.save
      settle_on_create(@entry)
      redirect_to financial_entries_path, notice: "Lançamento criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    @entry.assign_attributes(financial_entry_params)

    if @entry.amount_cents.to_i < @entry.paid_cents
      @entry.errors.add(:amount_cents, "não pode ser menor que o já pago (#{helpers.number_to_currency(@entry.paid_cents / 100.0)})")
      return render :edit, status: :unprocessable_content
    end

    if @entry.save
      redirect_to financial_entries_path, notice: "Lançamento atualizado!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @entry.destroy!
    redirect_to financial_entries_path, notice: "Lançamento removido!"
  end

  def settle
    date = params[:settled_on].presence || Date.current
    @entry.settle!(date)
    redirect_back fallback_location: financial_entries_path,
                  notice: "#{settlement_noun(@entry)} registrada."
  end

  def unsettle
    @entry.unsettle!
    redirect_back fallback_location: financial_entries_path,
                  notice: "Lançamento reaberto (em aberto novamente)."
  end

  private

  def render_financial_report_pdf
    render pdf: "relatorio-financeiro",
          template: "financial_entries/index",
          layout: "pdf",
          encoding: "UTF-8",
          page_size: "A4",
          margin: { top: 10, bottom: 10, left: 8, right: 8 }
  end

  def per_page
    requested = params[:per_page].to_i
    PER_PAGE_OPTIONS.include?(requested) ? requested : PER_PAGE_OPTIONS.first
  end

  def set_entry
    @entry = FinancialEntry.find(params[:id])
  end

  def settlement_noun(entry)
    entry.receivable? ? "Baixa (recebimento)" : "Baixa (pagamento)"
  end

  # Checkbox "já liquidado" (só na criação) registra o pagamento integral.
  # Depois de criado, a liquidação é feita pelos pagamentos do lançamento.
  def settle_on_create(entry)
    return unless params.dig(:financial_entry, :mark_settled) == "1"

    entry.settle!(params.dig(:financial_entry, :settled_on).presence || entry.occurred_on)
  end

  def financial_entry_params
    params.require(:financial_entry).permit(
      :entry_type,   # income/expense
      :stage,        # juvenile/growout/general
      :occurred_on,
      :due_on,
      :amount_cents,
      :description,
      :notes,
      :unit_id,
      :batch_id
    )
  end
end
