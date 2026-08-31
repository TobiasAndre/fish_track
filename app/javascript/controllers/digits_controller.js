// app/javascript/controllers/digits_controller.js
import { Controller } from "@hotwired/stimulus"

// Restricts a text input to digits only. Strips anything that is not 0-9 on
// initial render and on every input (which also covers paste and drag-drop).
// Use together with inputmode="numeric" so mobile keyboards show the number pad.
export default class extends Controller {
  connect() {
    this.strip()
  }

  strip() {
    const digitsOnly = this.element.value.replace(/\D/g, "")

    if (this.element.value !== digitsOnly) {
      this.element.value = digitsOnly
    }
  }
}
