class FeedingTablesController < ApplicationController
  before_action :set_feeding_table, only: %i[edit update destroy]
  before_action :load_ranges, only: %i[edit update]

  def index
    @feeding_tables =
      FeedingTable
        .includes(:feeding_strategy_items)
        .order(:name)

    @weight_ranges_count = FeedingWeightRange.count
    @temperature_ranges_count = FeedingTemperatureRange.count
  end

  def new
    @feeding_table = FeedingTable.new
  end

  def create
    @feeding_table = FeedingTable.new(feeding_table_params)

    if @feeding_table.save
      redirect_to edit_feeding_table_path(@feeding_table), notice: "Tabela criada. Agora preencha os percentuais."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @feeding_strategy_item = @feeding_table.feeding_strategy_items.build
    build_matrix
  end

  def update
    if @feeding_table.update(feeding_table_params)
      redirect_to edit_feeding_table_path(@feeding_table), notice: "Tabela atualizada com sucesso."
    else
      @feeding_strategy_item = @feeding_table.feeding_strategy_items.build
      build_matrix
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @feeding_table.destroy
    redirect_to feeding_tables_path, notice: "Tabela removida com sucesso."
  end

  def print
    @feeding_table = FeedingTable.find(params[:id])
    load_print_data(@feeding_table)

    respond_to do |format|
      format.html { render layout: false }
      format.pdf do
        html = render_to_string(
          template: "feeding_tables/print",
          layout: "pdf",
          formats: [:html]
        )

        pdf = WickedPdf.new.pdf_from_string(
          html,
          page_size: "A4",
          encoding: "UTF-8",
          margin: { top: 10, bottom: 10, left: 10, right: 10 }
        )

        send_data pdf,
                  filename: "arracoamento-#{@feeding_table.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @feeding_table = FeedingTable.find_by!(id: params[:id], share_token: params[:share_token])
      load_print_data(@feeding_table)

      respond_to do |format|
        format.pdf do
          render pdf: "arracoamento-#{@feeding_table.id}",
                template: "feeding_tables/print",
                layout: "pdf",
                formats: [:html],
                encoding: "UTF-8",
                page_size: "A4"
        end
      end
    end
  end

  private

  def load_print_data(feeding_table)
    @weight_ranges = FeedingWeightRange.order(:weight_from)
    @temperature_ranges = FeedingTemperatureRange.order(:temperature_from)
    @strategy_matrix = feeding_table.feeding_strategy_items.index_by do |item|
      [item.feeding_weight_range_id, item.feeding_temperature_range_id]
    end
  end

  def set_feeding_table
    @feeding_table = FeedingTable.find(params[:id])
  end

  def load_ranges
    @weight_ranges = FeedingWeightRange.order(:weight_from)
    @temperature_ranges = FeedingTemperatureRange.order(:temperature_from)
  end

  def build_matrix
    @strategy_items =
      @feeding_table
        .feeding_strategy_items
        .includes(:feeding_weight_range, :feeding_temperature_range)

    @strategy_matrix = @strategy_items.index_by do |item|
      [item.feeding_weight_range_id, item.feeding_temperature_range_id]
    end
  end

  def feeding_table_params
    params.require(:feeding_table).permit(:name, :description)
  end
end