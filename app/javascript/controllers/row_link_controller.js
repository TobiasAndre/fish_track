import { Controller } from "@hotwired/stimulus"

// Torna a linha inteira clicável: clicar em qualquer ponto dela aciona o link
// marcado com data-row-link-target="link" (links e botões próprios seguem normais).
export default class extends Controller {
  static targets = ["link"]

  open(event) {
    if (event.target.closest("a, button, input, select, textarea, label")) return
    if (window.getSelection()?.toString()) return

    this.linkTarget.click()
  }
}
