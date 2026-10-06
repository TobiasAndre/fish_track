import { Controller } from "@hotwired/stimulus"

// Galeria das fotos de uma biometria, numa janela (<dialog>): foto grande,
// anterior/próxima (botões ou setas do teclado), miniaturas e link para a
// original. Esc ou clique fora fecham.
//   botão: data-action="photo-gallery#open"
//          data-photo-gallery-photos-param='["url1","url2"]'
//          data-photo-gallery-title-param="Biometria de 06/10/2026"
export default class extends Controller {
  static targets = ["dialog", "image", "title", "counter", "thumbnails", "original", "previous", "next"]

  open(event) {
    this.photos = event.params.photos || []
    if (!this.photos.length) return

    this.titleTarget.textContent = event.params.title || "Fotos"
    this.renderThumbnails()
    this.show(0)
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  previous() {
    this.show((this.index - 1 + this.photos.length) % this.photos.length)
  }

  next() {
    this.show((this.index + 1) % this.photos.length)
  }

  select(event) {
    this.show(Number(event.params.index))
  }

  keydown(event) {
    if (!this.dialogTarget.open) return
    if (event.key === "ArrowLeft") this.previous()
    if (event.key === "ArrowRight") this.next()
  }

  // Clique no fundo escuro (fora do painel) fecha.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  show(index) {
    this.index = index
    const url = this.photos[index]

    this.imageTarget.src = url
    this.originalTarget.href = url
    this.counterTarget.textContent = `${index + 1} de ${this.photos.length}`

    const single = this.photos.length < 2
    this.previousTarget.hidden = single
    this.nextTarget.hidden = single
    this.thumbnailsTarget.hidden = single

    this.thumbnailsTarget.querySelectorAll("button").forEach((button, position) => {
      button.classList.toggle("ring-2", position === index)
      button.classList.toggle("ring-indigo-500", position === index)
      button.classList.toggle("opacity-60", position !== index)
    })
  }

  renderThumbnails() {
    this.thumbnailsTarget.replaceChildren(...this.photos.map((url, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "shrink-0 rounded-lg overflow-hidden transition hover:opacity-100"
      button.title = `Foto ${index + 1}`
      button.dataset.action = "photo-gallery#select"
      button.dataset.photoGalleryIndexParam = index

      const img = document.createElement("img")
      img.src = url
      img.alt = `Foto ${index + 1}`
      img.loading = "lazy"
      img.className = "h-16 w-16 object-cover"

      button.appendChild(img)
      return button
    }))
  }
}
