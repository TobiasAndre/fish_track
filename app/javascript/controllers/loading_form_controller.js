// app/javascript/controllers/loading_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "totalWeight",
    "avgWeight",
    "quantity",
    "pricePerKg",
    "pricePerKgCents",
    "thousandValue",
    "thousandValueCents",
    "freightCost",
    "freightCostCents",
    "loadingCost",
    "loadingCostCents"
  ]

  connect() {
    console.log("LoadingFormController connected")
    this.formatInitialCurrencyValues()
    this.recalculate()
  }

  formatDecimalInput(event) {
    let value = event.currentTarget.value

    value = value.replace(/[^0-9,\.]/g, "")

    const parts = value.split(/[,.]/)
    if (parts.length > 2) {
      value = parts[0] + "," + parts[1]
    }

    event.currentTarget.value = value

    this.recalculate()
  }

  recalculate() {
    const totalWeightKg = this.parseLocalizedNumber(this.totalWeightTarget.value)
    const avgWeightG = this.parseLocalizedNumber(this.avgWeightTarget.value)

    const quantity =
      totalWeightKg > 0 && avgWeightG > 0
        ? Math.ceil((totalWeightKg * 1000) / avgWeightG)
        : 0

    this.quantityTarget.value =
      quantity > 0 ? this.formatInteger(quantity) : ""
  }

  maskCurrency(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "")

    if (!digits) {
      input.value = ""
      this.syncCurrencyHiddenTarget(input, 0)
      return
    }

    const cents = Number(digits)
    input.value = this.formatCurrency(cents / 100)

    this.syncCurrencyHiddenTarget(input, cents)
  }

  syncCurrencyHiddenTarget(input, cents) {
    if (this.hasPricePerKgTarget && input === this.pricePerKgTarget && this.hasPricePerKgCentsTarget) {
      this.pricePerKgCentsTarget.value = cents
    }

    if (this.hasThousandValueTarget && input === this.thousandValueTarget && this.hasThousandValueCentsTarget) {
      this.thousandValueCentsTarget.value = cents
    }

    if (this.hasFreightCostTarget && input === this.freightCostTarget && this.hasFreightCostCentsTarget) {
      this.freightCostCentsTarget.value = cents
    }

    if (this.hasLoadingCostTarget && input === this.loadingCostTarget && this.hasLoadingCostCentsTarget) {
      this.loadingCostCentsTarget.value = cents
    }
  }

  formatInitialCurrencyValues() {
    this.formatInitialCurrency(this.pricePerKgTarget)
    this.formatInitialCurrency(this.thousandValueTarget)
    this.formatInitialCurrency(this.freightCostTarget)
    this.formatInitialCurrency(this.loadingCostTarget)
  }

  formatInitialCurrency(input) {
    if (!input) return

    const digits = input.value.replace(/\D/g, "")
    if (!digits) return

    input.value = this.formatCurrency(Number(digits) / 100)
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

  formatInteger(value) {
    return String(Math.round(Number(value || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format(Number(value || 0))
  }
}
