// app/javascript/controllers/batch_event_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "type",
    "biometryRow",
    "feedKgRow",
    "quantity",
    "totalWeight",
    "volume",
    "avgWeight",
    "biomass"
  ]

  connect() {
    this.toggle()
    this.recalculate()
  }

  toggle() {
    const eventType = this.typeTarget.value

    const isBiometry = eventType === "biometrics"
    const isFeeding = eventType === "feeding"

    this.toggleTarget("biometryRow", isBiometry)
    this.toggleTarget("feedKgRow", isFeeding)

    if (!isBiometry) {
      this.clearBiometryFields()
    }
  }

  recalculate() {
    if (!this.hasTypeTarget || this.typeTarget.value !== "biometrics") return

    const quantity = this.parseNumber(this.hasQuantityTarget ? this.quantityTarget.value : "")
    const totalWeightKg = this.parseNumber(this.hasTotalWeightTarget ? this.totalWeightTarget.value : "")
    const volume = this.parseNumber(this.hasVolumeTarget ? this.volumeTarget.value : "")

    let avgWeightG = 0
    let biomass = 0

    if (quantity > 0 && totalWeightKg > 0) {
      avgWeightG = (totalWeightKg / quantity) * 1000
    }

    if (volume > 0 && avgWeightG > 0) {
      biomass = volume * (avgWeightG / 1000)
    }

    if (this.hasAvgWeightTarget) {
      this.avgWeightTarget.value = avgWeightG > 0 ? avgWeightG.toFixed(2) : ""
    }

    if (this.hasBiomassTarget) {
      this.biomassTarget.value = biomass > 0 ? biomass.toFixed(2) : ""
    }
  }

  toggleTarget(targetName, show) {
    const targetProperty = `has${this.capitalize(targetName)}Target`
    const elementProperty = `${targetName}Target`

    if (!this[targetProperty]) return

    this[elementProperty].classList.toggle("hidden", !show)
  }

  clearBiometryFields() {
    if (this.hasAvgWeightTarget) this.avgWeightTarget.value = ""
    if (this.hasBiomassTarget) this.biomassTarget.value = ""
  }

  parseNumber(value) {
    if (value == null || value === "") return 0

    const normalized = String(value).trim().replace(",", ".")
    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }
}
