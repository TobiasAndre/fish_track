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
end
