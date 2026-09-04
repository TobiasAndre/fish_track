class FinancialEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entry, only: [:edit, :update, :destroy, :settle, :unsettle]

  PER_PAGE_OPTIONS = [10, 20, 30, 50].freeze
  STATUS_OPTIONS = %w[pending settled overdue].freeze

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
    @pending_payable_cents    = base.pending.payable.sum(:amount_cents)
    @pending_receivable_cents = base.pending.receivable.sum(:amount_cents)
    @overdue_cents            = base.overdue.sum(:amount_cents)
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
      redirect_to financial_entries_path, notice: "Lançamento criado!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @entry.update(financial_entry_params)
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

  def financial_entry_params
    attrs = params.require(:financial_entry).permit(
      :entry_type,   # income/expense
      :stage,        # juvenile/growout/general
      :occurred_on,
      :due_on,
      :amount_cents,
      :description,
      :notes,
      :unit_id,
      :batch_id,
      :settled_on
    )

    # Checkbox "já liquidado" controla se o lançamento nasce/fica com baixa.
    if params.dig(:financial_entry, :mark_settled) == "1"
      attrs[:settled_on] = attrs[:settled_on].presence ||
                           attrs[:occurred_on].presence ||
                           Date.current
    else
      attrs[:settled_on] = nil
    end

    attrs
  end
end
