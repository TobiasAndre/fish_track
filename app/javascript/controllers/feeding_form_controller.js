// app/javascript/controllers/feeding_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "quantity",
    "totalValue",
    "totalCents",
    "pricePerKg"
  ]

  connect() {
    this.formatInitialCurrencyValue()
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

  maskCurrency(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "")

    if (!digits) {
      input.value = ""
      this.totalCentsTarget.value = 0
      this.recalculate()
      return
    }

    const cents = Number(digits)
    input.value = this.formatCurrency(cents / 100)
    this.moveCursorToEnd(input)

    this.totalCentsTarget.value = cents
    this.recalculate()
  }

  focusCurrencyEnd(event) {
    this.moveCursorToEnd(event.currentTarget)
  }

  moveCursorToEnd(input) {
    const length = input.value.length
    input.setSelectionRange(length, length)
  }

  recalculate() {
    const quantityKg = this.parseLocalizedNumber(this.quantityTarget.value)
    const totalCents = Number(this.totalCentsTarget.value || 0)

    const pricePerKgCents = quantityKg > 0 ? totalCents / quantityKg : 0

    this.pricePerKgTarget.textContent = this.formatCurrency(pricePerKgCents / 100)
  }

  formatInitialCurrencyValue() {
    const input = this.totalValueTarget
    if (!input) return

    const digits = input.value.replace(/\D/g, "")
    if (!digits) return

    input.value = this.formatCurrency(Number(digits) / 100)
  }

  parseLocalizedNumber(value) {
    if (value == null || value === "") return 0

    const stringValue = String(value).trim()
    if (!stringValue) return 0

    const normalized = stringValue.includes(",")
      ? stringValue.replace(/\./g, "").replace(",", ".")
      : stringValue

    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format(Number(value || 0))
  }
}
