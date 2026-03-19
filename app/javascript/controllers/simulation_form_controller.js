import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "quantity",
    "avgWeight",
    "totalWeight",
    "pricePerKg",
    "loadingCost",
    "freightCost",
    "loadingCount",
    "grandTotal",
    "pricePerKgCents",
    "loadingCostCents",
    "freightCostCents",
    "totalCents"
  ]

  connect() {
    this.formatInitialValues()
    this.recalculate()
  }

  formatInitialValues() {
    if (this.hasQuantityTarget) {
      const quantity = this.parseInteger(this.quantityTarget.value)
      this.quantityTarget.value = this.formatIntegerValue(quantity)
    }

    if (this.hasLoadingCountTarget) {
      const loadingCount = this.parseInteger(this.loadingCountTarget.value)
      this.loadingCountTarget.value = loadingCount || 1
    }

    if (this.hasTotalWeightTarget) {
      const totalWeight = this.parseDecimal(this.totalWeightTarget.value)
      this.totalWeightTarget.value = this.formatDecimal(totalWeight, 3)
    }
  }

  recalculate() {
    const quantity = this.parseInteger(this.quantityTarget.value)
    const avgWeight = this.parseDecimal(this.avgWeightTarget.value)
    const totalWeight = quantity * avgWeight

    const pricePerKgCents = this.parseCurrencyToCents(this.pricePerKgTarget.value)
    const loadingCostCents = this.parseCurrencyToCents(this.loadingCostTarget.value)
    const freightCostCents = this.parseCurrencyToCents(this.freightCostTarget.value)
    const loadingCount = this.parseInteger(this.loadingCountTarget.value) || 1

    const fishTotalCents = Math.round(totalWeight * pricePerKgCents)
    const logisticsTotalCents = (loadingCostCents + freightCostCents) * loadingCount
    const grandTotalCents = fishTotalCents + logisticsTotalCents

    this.totalWeightTarget.value = this.formatDecimal(totalWeight, 3)
    this.grandTotalTarget.textContent = this.formatCurrency(grandTotalCents)

    this.pricePerKgCentsTarget.value = pricePerKgCents
    this.loadingCostCentsTarget.value = loadingCostCents
    this.freightCostCentsTarget.value = freightCostCents
    this.totalCentsTarget.value = grandTotalCents
  }

  formatInteger(event) {
    const input = event.currentTarget
    const value = this.parseInteger(input.value)
    input.value = this.formatIntegerValue(value)
    this.recalculate()
  }

  maskCurrency(event) {
    const input = event.currentTarget
    const cents = this.parseDigitsToCents(input.value)
    input.value = this.formatCurrency(cents)
    this.recalculate()
  }

  parseInteger(value) {
    const digits = String(value || "").replace(/\D/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  parseDecimal(value) {
    if (!value) return 0

    const stringValue = String(value).trim()

    if (stringValue.includes(",")) {
      const normalized = stringValue.replace(/\./g, "").replace(",", ".")
      const parsed = parseFloat(normalized)
      return Number.isNaN(parsed) ? 0 : parsed
    }

    const parsed = parseFloat(stringValue)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  parseDigitsToCents(value) {
    const digits = String(value || "").replace(/\D/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  parseCurrencyToCents(value) {
    return this.parseDigitsToCents(value)
  }

  formatIntegerValue(value) {
    return new Intl.NumberFormat("pt-BR", {
      maximumFractionDigits: 0
    }).format(Number(value || 0))
  }

  formatDecimal(value, decimals = 3) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    }).format(Number(value || 0))
  }

  formatCurrency(cents) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format((cents || 0) / 100)
  }
}
