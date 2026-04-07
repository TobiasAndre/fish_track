// app/javascript/controllers/biometry_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "previousBiomass",
    "previousAvgWeight",
    "previousOccurredOn",
    "currentAvgWeight",
    "currentStockQuantity",
    "occurredOn",
    "volume",
    "quantity",
    "totalWeight",
    "avgWeight",
    "biomass",
    "weightGain",
    "gpd",
    "feedKg",
    "feedConversion"
  ]

  connect() {
    this.recalculate()
  }

  formatIntegerInput(event) {
    const input = event.target
    const digits = (input.value || "").replace(/\D/g, "")
    input.value = this.formatIntegerBR(digits)
    this.recalculate()
  }

  formatDecimalInput(event) {
    const input = event.target
    input.value = this.normalizeDecimalTyping(input.value)
    this.recalculate()
  }

  recalculate() {
    const quantity = this.parsePtBrNumber(this.quantityValue())
    const totalWeightKg = this.parsePtBrNumber(this.totalWeightValue())
    const feedKg = this.parsePtBrNumber(this.feedKgValue())
    const currentStockQuantity = this.parsePtBrNumber(this.currentStockQuantityValue())

    const previousBiomass = this.parsePtBrNumber(this.previousBiomassValue())
    const previousAvgWeight = this.parsePtBrNumber(this.previousAvgWeightValue())
    const previousOccurredOn = this.previousOccurredOnValue()
    const occurredOn = this.occurredOnValue()

    let avgWeightG = 0
    if (quantity > 0 && totalWeightKg > 0) {
      avgWeightG = (totalWeightKg / quantity) * 1000
    }

    let biomassKg = 0
    if (currentStockQuantity > 0 && avgWeightG > 0) {
      biomassKg = (currentStockQuantity * avgWeightG) / 1000
    }

    let weightGainKg = 0
    if (avgWeightG > 0 && previousAvgWeight > 0 && currentStockQuantity > 0) {
      weightGainKg = ((avgWeightG - previousAvgWeight) * currentStockQuantity) / 1000
    } else if (biomassKg > 0 && previousBiomass > 0) {
      // fallback caso não exista peso médio anterior
      weightGainKg = biomassKg - previousBiomass
    }

    const days = this.daysBetween(previousOccurredOn, occurredOn)

    let gpd = 0
    if (avgWeightG > 0 && previousAvgWeight > 0 && days > 0) {
      gpd = (avgWeightG - previousAvgWeight) / days
    }

    let feedConversion = 0
    if (feedKg > 0 && weightGainKg > 0) {
      feedConversion = feedKg / weightGainKg
    }

    console.log({
      quantity,
      totalWeightKg,
      avgWeightG,
      previousAvgWeight,
      currentStockQuantity
    })

    this.setValue(this.avgWeightTarget, avgWeightG, 3)
    this.setValue(this.biomassTarget, biomassKg, 3)
    this.setValueAllowNegative(this.weightGainTarget, weightGainKg, 3)
    this.setValueAllowNegative(this.gpdTarget, gpd, 3)
    this.setValue(this.feedConversionTarget, feedConversion, 3)
  }

  quantityValue() {
    return this.hasQuantityTarget ? this.quantityTarget.value : ""
  }

  totalWeightValue() {
    return this.hasTotalWeightTarget ? this.totalWeightTarget.value : ""
  }

  feedKgValue() {
    return this.hasFeedKgTarget ? this.feedKgTarget.value : ""
  }

  currentStockQuantityValue() {
    return this.hasCurrentStockQuantityTarget ? this.currentStockQuantityTarget.value : ""
  }

  previousBiomassValue() {
    return this.hasPreviousBiomassTarget ? this.previousBiomassTarget.value : ""
  }

  previousAvgWeightValue() {
    return this.hasPreviousAvgWeightTarget ? this.previousAvgWeightTarget.value : ""
  }

  previousOccurredOnValue() {
    return this.hasPreviousOccurredOnTarget ? this.previousOccurredOnTarget.value : ""
  }

  occurredOnValue() {
    return this.hasOccurredOnTarget ? this.occurredOnTarget.value : ""
  }

  setValue(target, number, precision = 3) {
    if (!target) return
    target.value = number > 0 ? this.formatDecimalBR(number, precision) : ""
  }

  setValueAllowNegative(target, number, precision = 3) {
    if (!target) return
    target.value = number !== 0 ? this.formatDecimalBR(number, precision) : ""
  }

  parsePtBrNumber(value) {
    if (value === null || value === undefined || value === "") return 0

    const stringValue = String(value).trim()

    if (!stringValue) return 0

    // Caso tenha vírgula, assume formato pt-BR:
    // 1.234,56 -> 1234.56
    if (stringValue.includes(",")) {
      const normalized = stringValue
        .replace(/\./g, "")
        .replace(",", ".")

      const number = parseFloat(normalized)
      return Number.isFinite(number) ? number : 0
    }

    // Caso não tenha vírgula, assume ponto como decimal normal:
    // 4.82 -> 4.82
    // 1200000 -> 1200000
    const number = parseFloat(stringValue)
    return Number.isFinite(number) ? number : 0
  }

  normalizeDecimalTyping(value) {
    if (!value) return ""

    let cleaned = String(value).replace(/[^\d,]/g, "")
    const firstComma = cleaned.indexOf(",")

    if (firstComma !== -1) {
      cleaned =
        cleaned.slice(0, firstComma + 1) +
        cleaned.slice(firstComma + 1).replace(/,/g, "")
    }

    const parts = cleaned.split(",")
    let integerPart = parts[0].replace(/^0+(?=\d)/, "")
    if (integerPart === "") integerPart = "0"

    integerPart = this.formatIntegerBR(integerPart)

    if (parts.length > 1) {
      return `${integerPart},${parts[1].slice(0, 3)}`
    }

    return integerPart
  }

  formatIntegerBR(value) {
    const digits = String(value || "").replace(/\D/g, "")
    if (!digits) return ""

    return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  formatDecimalBR(number, precision = 3) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: precision,
      maximumFractionDigits: precision
    }).format(number)
  }

  daysBetween(startDate, endDate) {
    if (!startDate || !endDate) return 0

    const start = new Date(`${startDate}T00:00:00`)
    const end = new Date(`${endDate}T00:00:00`)

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0

    const diffMs = end.getTime() - start.getTime()
    const days = Math.round(diffMs / 86400000)

    return days > 0 ? days : 0
  }
}
