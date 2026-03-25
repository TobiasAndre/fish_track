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
    "biomass",
    "weightGain",
    "previousBiomass"
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

    const quantity = this.parseNumber(
      this.hasQuantityTarget ? this.quantityTarget.value : ""
    )
    const totalWeightKg = this.parseNumber(
      this.hasTotalWeightTarget ? this.totalWeightTarget.value : ""
    )
    const volume = this.parseNumber(
      this.hasVolumeTarget ? this.volumeTarget.value : ""
    )
    const previousBiomass = this.parseNumber(
      this.hasPreviousBiomassTarget ? this.previousBiomassTarget.value : ""
    )

    let avgWeightG = 0
    let biomass = 0
    let weightGainKg = 0

    if (quantity > 0 && totalWeightKg > 0) {
      avgWeightG = (totalWeightKg / quantity) * 1000
    }

    if (volume > 0 && avgWeightG > 0) {
      biomass = volume * (avgWeightG / 1000)
    }

    if (biomass > 0) {
      weightGainKg = biomass - previousBiomass
    }

    if (this.hasAvgWeightTarget) {
      this.avgWeightTarget.value = avgWeightG > 0 ? avgWeightG.toFixed(2) : ""
    }

    if (this.hasBiomassTarget) {
      this.biomassTarget.value = biomass > 0 ? biomass.toFixed(2) : ""
    }

    if (this.hasWeightGainTarget) {
      this.weightGainTarget.value = biomass > 0 ? weightGainKg.toFixed(2) : ""
    }
  }

  formatDecimalInput(event) {
    const input = event.currentTarget
    const value = this.parseDecimalDigits(input.value)
    input.value = value ? this.formatDecimal(value, 2) : ""
    this.recalculate()
  }

  formatInitialValues() {
    if (this.hasVolumeTarget) {
      const volume = this.parseNumber(this.volumeTarget.value)
      this.volumeTarget.value = volume > 0 ? this.formatDecimal(volume, 2) : ""
    }

    if (this.hasBiomassTarget) {
      const biomass = this.parseNumber(this.biomassTarget.value)
      this.biomassTarget.value = biomass > 0 ? this.formatDecimal(biomass, 2) : ""
    }

    if (this.hasWeightGainTarget) {
      const weightGain = this.parseNumber(this.weightGainTarget.value)
      this.weightGainTarget.value = weightGain !== 0 ? this.formatDecimal(weightGain, 2) : ""
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
    if (this.hasWeightGainTarget) this.weightGainTarget.value = ""
  }

  parseDecimalDigits(value) {
    const digits = String(value || "").replace(/\D/g, "")
    if (!digits) return 0

    return parseFloat(digits) / 100
  }

  formatDecimal(value, decimals = 2) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    }).format(Number(value || 0))
  }

  parseNumber(value) {
    if (value == null || value === "") return 0

    const stringValue = String(value).trim()

    // remove separador de milhar
    const normalized = stringValue.replace(/\./g, "").replace(",", ".")

    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  formatIntegerInput(event) {
    let value = event.target.value.replace(/\D/g, "")

    if (!value) {
      event.target.value = ""
      this.recalculate()
      return
    }

    event.target.value = this.formatWithDelimiter(value)
    this.recalculate()
  }

  formatWithDelimiter(value) {
    return value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }
}
