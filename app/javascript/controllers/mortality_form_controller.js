// app/javascript/controllers/mortality_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "avgWeight", "weightLoss", "currentAvgWeight"]

  connect() {
    this.recalculate()
  }

  formatQuantityInput(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "")

    input.value = digits ? this.formatInteger(digits) : ""

    this.recalculate()
  }

  recalculate() {
    const quantity = this.parseLocalizedNumber(this.quantityTarget.value)
    const avgWeightG = this.parseStoredNumber(this.currentAvgWeightTarget.value)

    const weightLossKg =
      quantity > 0 && avgWeightG > 0
        ? (quantity * avgWeightG) / 1000
        : 0

    this.avgWeightTarget.value =
      avgWeightG > 0 ? this.formatDecimal(avgWeightG, 2) : ""

    this.weightLossTarget.value =
      weightLossKg > 0 ? this.formatDecimal(weightLossKg, 3) : ""
  }

  parseLocalizedNumber(value) {
    if (value == null || value === "") return 0

    const normalized = String(value)
      .trim()
      .replace(/\./g, "")
      .replace(",", ".")

    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  parseStoredNumber(value) {
    if (value == null || value === "") return 0

    const parsed = parseFloat(String(value).trim().replace(",", "."))

    return Number.isNaN(parsed) ? 0 : parsed
  }

  formatDecimal(value, decimals = 2) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    }).format(Number(value || 0))
  }

  formatInteger(value) {
    return String(value || "").replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }
}
