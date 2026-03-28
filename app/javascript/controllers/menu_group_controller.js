// app/javascript/controllers/menu_group_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    open: Boolean
  }

  connect() {
    this.applyState()
  }

  openValueChanged() {
    this.applyState()
  }

  applyState() {
    this.element.open = this.openValue
  }
}
