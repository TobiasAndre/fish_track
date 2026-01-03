import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "quantityRow", "avgWeightRow", "feedKgRow"]

  connect() {
    this.toggle()
  }

  toggle() {
    const t = this.typeTarget.value

    // defaults: esconder tudo
    this.hide(this.quantityRowTarget)
    this.hide(this.avgWeightRowTarget)
    this.hide(this.feedKgRowTarget)

    // tipos -> campos
    if (t === "mortality" || t === "loading" || t === "transfer") {
      this.show(this.quantityRowTarget)
    }

    if (t === "biometrics") {
      this.show(this.avgWeightRowTarget)
      this.show(this.quantityRowTarget) // opcional: qtde amostrada
    }

    if (t === "feeding" || t === "daily_care") {
      this.show(this.feedKgRowTarget)
    }
  }

  show(el) {
    el.classList.remove("hidden")
  }

  hide(el) {
    el.classList.add("hidden")
  }
}
