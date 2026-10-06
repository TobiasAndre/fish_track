import { Controller } from "@hotwired/stimulus"
import { compressImage } from "image_compress"

// Campo de fotos do formulário de biometria: reduz as fotos escolhidas (câmera
// ou galeria) antes do envio, mostra as miniaturas e deixa tirar alguma antes de
// salvar. Respeita o limite de fotos por biometria (contando as já salvas).
export default class extends Controller {
  static targets = ["input", "previews", "hint"]
  static values = { existing: Number, max: Number }

  connect() {
    this.files = []
  }

  async select() {
    const chosen = [...this.inputTarget.files]
    if (!chosen.length) return

    const room = this.maxValue - this.existingValue - this.files.length
    const accepted = chosen.slice(0, Math.max(room, 0))
    if (accepted.length < chosen.length) this.hintTarget.textContent = `Limite de ${this.maxValue} fotos por biometria: ${chosen.length - accepted.length} foto(s) ficaram de fora.`

    this.setBusy(true)
    try {
      for (const file of accepted) this.files.push(await compressImage(file))
    } finally {
      this.setBusy(false)
      this.sync()
    }
  }

  remove(event) {
    this.files.splice(Number(event.params.index), 1)
    this.sync()
  }

  // Põe a lista atual (já reduzida) de volta no campo, que é o que o formulário envia.
  sync() {
    const transfer = new DataTransfer()
    this.files.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    this.renderPreviews()
  }

  renderPreviews() {
    this.previewsTarget.querySelectorAll("img").forEach((img) => URL.revokeObjectURL(img.src))

    this.previewsTarget.replaceChildren(...this.files.map((file, index) => {
      const wrapper = document.createElement("div")
      wrapper.className = "relative"

      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.alt = file.name
      img.className = "h-20 w-20 rounded-lg object-cover border border-gray-200 dark:border-gray-700"

      const button = document.createElement("button")
      button.type = "button"
      button.textContent = "✕"
      button.title = "Tirar esta foto"
      button.className = "absolute -top-2 -right-2 h-6 w-6 rounded-full bg-gray-900/80 text-xs text-white"
      button.dataset.action = "photo-picker#remove"
      button.dataset.photoPickerIndexParam = index

      wrapper.append(img, button)
      return wrapper
    }))
  }

  setBusy(busy) {
    const submit = this.element.closest("form")?.querySelector('[type="submit"]')
    if (submit) submit.disabled = busy
    if (busy) this.hintTarget.textContent = "Preparando as fotos…"
    else if (this.hintTarget.textContent === "Preparando as fotos…") this.hintTarget.textContent = this.hintTarget.dataset.default
  }
}
