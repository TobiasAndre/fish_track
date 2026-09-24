import { Controller } from "@hotwired/stimulus"

// Abre uma URL em nova aba ao aparecer na tela (ex.: link de WhatsApp depois de
// gerar um relatório). Substitui <script> inline bloqueado pela CSP.
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (this.urlValue) window.open(this.urlValue, "_blank", "noopener")
  }
}
