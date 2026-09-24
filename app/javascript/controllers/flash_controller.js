import { Controller } from "@hotwired/stimulus"
import Swal from "sweetalert2"

// Mostra a mensagem flash (notice/alert) como toast. Substitui o <script>
// inline do partial, que a CSP bloqueia (e cujo nonce, por requisição, não
// valeria nas navegações do Turbo).
export default class extends Controller {
  static values = { message: String, type: { type: String, default: "success" } }

  connect() {
    if (!this.messageValue) return

    const error = this.typeValue === "error"

    // Elemento (não string): o SweetAlert2 renderiza `title` como HTML, e a
    // mensagem pode conter texto vindo de dados do usuário.
    const title = document.createElement("span")
    title.textContent = this.messageValue

    Swal.fire({
      toast: true,
      position: "top-end",
      icon: error ? "error" : "success",
      title,
      showConfirmButton: false,
      timer: error ? 4000 : 3000,
      timerProgressBar: true
    })
  }
}
