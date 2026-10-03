module WhatsappHelper
  def whatsapp_share_url(message:, url:)
    "https://wa.me/?text=#{CGI.escape("#{message} #{url}")}"
  end

  def whatsapp_share_link_to(message:, url:, **html_options, &block)
    html_options[:target] ||= "_blank"
    html_options[:rel] ||= "noopener"
    html_options[:title] ||= "Compartilhar no WhatsApp"
    html_options[:class] ||= "inline-flex items-center justify-center rounded-lg bg-green-500 p-2 text-white hover:bg-green-600 transition"

    link_to whatsapp_share_url(message: message, url: url), html_options, &block
  end

  # Monta a URL do WhatsApp para compartilhar o PDF de um carregamento.
  # Retorna nil quando não há empresa selecionada na sessão (ex.: em testes
  # que autenticam sem passar pelo seletor de empresa), para o mesmo motivo
  # pelo qual o auto-open após salvar também é condicionado ao tenant.
  def loading_event_whatsapp_url(event)
    tenant_name = session[:tenant_name].presence
    return if tenant_name.blank?

    event.regenerate_share_token if event.share_token.blank?

    company = current_company || Company.find_by(tenant_name: tenant_name)
    message = "Carregamento #{company&.name}: #{event.customer&.name || event.batch_stocking&.display_name}"

    pdf_url = shared_loading_event_pdf_url(
      tenant_name: tenant_name,
      id: event.id,
      share_token: event.share_token,
      format: :pdf
    )

    whatsapp_share_url(message: message, url: pdf_url)
  end

  # URL do WhatsApp para enviar ao funcionário o demonstrativo de pagamento da
  # competência. Nil sem empresa na sessão, como no carregamento.
  def payroll_statement_whatsapp_url(employee, year:, month:)
    tenant_name = session[:tenant_name].presence
    return if tenant_name.blank?

    employee.regenerate_share_token if employee.share_token.blank?

    company = current_company || Company.find_by(tenant_name: tenant_name)
    message = "Demonstrativo de pagamento #{format('%02d', month)}/#{year} - #{employee.name}#{" (#{company.name})" if company}:"

    pdf_url = shared_payroll_statement_pdf_url(
      tenant_name: tenant_name, id: employee.id, year: year, month: month,
      share_token: employee.share_token, format: :pdf
    )

    whatsapp_share_url(message: message, url: pdf_url)
  end
end
