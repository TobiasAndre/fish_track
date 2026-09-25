import { Controller } from "@hotwired/stimulus"

// <dialog> modal preenchido por um Turbo Frame: abre quando o frame termina de
// carregar e fecha no botão, no Esc (nativo) ou clicando fora do conteúdo.
//   <dialog data-controller="dialog" data-action="turbo:frame-load->dialog#open click->dialog#backdrop">
//     <turbo-frame id="..." data-dialog-target="frame"></turbo-frame>
//   </dialog>
export default class extends Controller {
  static targets = ["frame"]

  open() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }

  // Clique no próprio <dialog> (fora do painel) = clique no fundo.
  backdrop(event) {
    if (event.target === this.element) this.close()
  }

  // Limpa o conteúdo ao fechar, para o próximo log não mostrar o anterior enquanto carrega.
  cleanup() {
    if (this.hasFrameTarget) this.frameTarget.innerHTML = ""
  }
}
