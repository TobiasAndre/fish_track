// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "confirmations"
import "pwa"

// Se uma requisição de Turbo Frame for respondida sem o frame (ex.: sessão expirada
// redireciona para o login), navega a página inteira em vez de mostrar "Content missing".
document.addEventListener("turbo:frame-missing", (event) => {
  event.preventDefault()
  event.detail.visit(event.detail.response.url)
})
