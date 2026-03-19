import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "quantity", "unitPrice", "total", "orderTotal"]

  connect() {
    this.recalculateAll()
  }

  recalculate() {
    this.recalculateAll()
  }

  formatCurrency(event) {
    const input = event.currentTarget
    const cents = this.parseDigitsToCents(input.value)
    input.value = this.formatCents(cents)
    this.recalculateAll()
  }

  recalculateAll() {
    let orderTotalCents = 0

    this.rowTargets.forEach((row) => {
      if (row.classList.contains("hidden")) return

      const quantityInput = row.querySelector('[data-order-items-target="quantity"]')
      const unitPriceInput = row.querySelector('[data-order-items-target="unitPrice"]')
      const totalInput = row.querySelector('[data-order-items-target="total"]')
      const unitPriceCentsInput = row.querySelector('input[name*="[unit_price_cents]"]')
      const totalCentsInput = row.querySelector('input[name*="[total_cents]"]')
      const destroyInput = row.querySelector('input[name*="[_destroy]"]')

      if (destroyInput && destroyInput.value === "1") return

      const quantity = this.parseDecimal(quantityInput?.value)
      const unitPriceCents = this.parseCurrencyStringToCents(unitPriceInput?.value)
      const totalCents = Math.round(quantity * unitPriceCents)

      if (unitPriceCentsInput) unitPriceCentsInput.value = unitPriceCents
      if (totalCentsInput) totalCentsInput.value = totalCents
      if (totalInput) totalInput.value = this.formatCents(totalCents)

      orderTotalCents += totalCents
    })

    if (this.hasOrderTotalTarget) {
      this.orderTotalTarget.textContent = this.formatCents(orderTotalCents)
    }
  }

  parseDecimal(value) {
    if (!value) return 0

    const normalized = String(value)
      .trim()
      .replace(/\./g, "")
      .replace(",", ".")

    const parsed = parseFloat(normalized)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  parseDigitsToCents(value) {
    const digits = String(value || "").replace(/\D/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  parseCurrencyStringToCents(value) {
    return this.parseDigitsToCents(value)
  }

  formatCents(cents) {
    const number = Number(cents || 0) / 100
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
    }).format(number)
  }
}
