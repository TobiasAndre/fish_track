class FinancialEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entry, only: [:edit, :update, :destroy]

  def index
    @q_stage = params[:stage].presence
    @q_from  = params[:from].presence
    @q_to    = params[:to].presence
    @q_type  = params[:entry_type].presence

    @entries = FinancialEntry.includes(:unit, :batch)
                             .order(occurred_on: :desc, created_at: :desc)

    @entries = @entries.where(stage: @q_stage) if @q_stage.present?
    @entries = @entries.where(entry_type: @q_type) if @q_type.present?
    @entries = @entries.where("occurred_on >= ?", @q_from) if @q_from.present?
    @entries = @entries.where("occurred_on <= ?", @q_to) if @q_to.present?

    @total_income_cents  = @entries.where(entry_type: "income").sum(:amount_cents)
    @total_expense_cents = @entries.where(entry_type: "expense").sum(:amount_cents)
    @balance_cents       = @total_income_cents - @total_expense_cents
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
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @entry.update(financial_entry_params)
      redirect_to financial_entries_path, notice: "Lançamento atualizado!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy!
    redirect_to financial_entries_path, notice: "Lançamento removido!"
  end

  private

  def set_entry
    @entry = FinancialEntry.find(params[:id])
  end

  def financial_entry_params
    params.require(:financial_entry).permit(
      :entry_type,   # income/expense
      :stage,        # juvenile/growout/general
      :occurred_on,
      :amount_cents,
      :description,
      :notes,
      :unit_id,
      :batch_id
    )
  end
end
