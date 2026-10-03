# Demonstrativo de pagamento de um funcionário numa competência (PDF), para o
# usuário enviar ao funcionário. O link público (share_pdf) usa o token do
# funcionário, o mesmo do acerto rescisório.
class PayrollStatementsController < ApplicationController
  before_action :authenticate_user!, except: :share_pdf

  def show
    @employee = Employee.find(params[:id])
    @statement = build_statement or return head(:not_found)
    @company = Company.find_by(tenant_name: session[:tenant_name])

    respond_to do |format|
      format.html { render :show, layout: "pdf" }
      format.pdf { render_statement_pdf }
    end
  end

  def share_pdf
    Apartment::Tenant.switch(params[:tenant_name]) do
      @employee = Employee.find_by!(id: params[:id], share_token: params[:share_token])
      @statement = build_statement or return head(:not_found)
      @company = Company.find_by(tenant_name: params[:tenant_name])

      respond_to do |format|
        format.pdf { render_statement_pdf }
      end
    end
  end

  private

  def build_statement
    PayrollStatement.new(@employee, year: params[:year] || Date.current.year, month: params[:month] || Date.current.month)
  rescue Date::Error
    nil
  end

  def render_statement_pdf
    html = render_to_string(template: "payroll_statements/show", layout: "pdf", formats: [:html])
    pdf = WickedPdf.new.pdf_from_string(html, page_size: "A4", encoding: "UTF-8", margin: { top: 10, bottom: 10, left: 10, right: 10 })

    send_data pdf,
              filename: "demonstrativo-#{@employee.name.parameterize}-#{@statement.year}-#{format('%02d', @statement.month)}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end
end
