// app/javascript/controllers/integer_mask_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("IntegerMaskController connected")
    this.formatInitial()
  }

  format(event) {
    let value = event.target.value.replace(/\D/g, "")

    if (!value) {
      event.target.value = ""
      return
    }

    event.target.value = this.formatWithDelimiter(value)
  }

  formatInitial() {
    let value = this.element.value?.toString().replace(/\D/g, "")

    if (value) {
      this.element.value = this.formatWithDelimiter(value)
    }
  }

  formatWithDelimiter(value) {
    return value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }
}
