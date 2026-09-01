// app/javascript/controllers/feeding_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "quantity",
    "totalValue",
    "totalCents",
    "pricePerKg",
    "occurredOn",
    "paymentTerm",
    "dueOn",
    "dueHintManual",
    "dueHintAuto"
  ]

  connect() {
    this.formatInitialCurrencyValue()
    this.recalculate()
    this.applyDueDate()
  }

  // Preenche a data de vencimento a partir da condição de pagamento
  // selecionada (data do lançamento + dias da 1ª parcela). Sem condição, o
  // campo volta a ser editável manualmente.
  applyDueDate() {
    if (!this.hasDueOnTarget || !this.hasPaymentTermTarget || !this.hasOccurredOnTarget) return

    const option = this.paymentTermTarget.options[this.paymentTermTarget.selectedIndex]
    const offset = option ? parseInt(option.dataset.firstOffset ?? "", 10) : NaN
    const baseDate = this.occurredOnTarget.value
    const usesTerm = Boolean(this.paymentTermTarget.value) && !Number.isNaN(offset) && Boolean(baseDate)

    if (usesTerm) {
      const date = new Date(`${baseDate}T00:00:00`)
      date.setDate(date.getDate() + offset)
      this.dueOnTarget.value = this.toISODate(date)
    }

    this.dueOnTarget.readOnly = usesTerm
    this.dueOnTarget.classList.toggle("bg-gray-50", usesTerm)
    this.dueOnTarget.classList.toggle("dark:bg-gray-900", usesTerm)

    if (this.hasDueHintManualTarget) this.dueHintManualTarget.hidden = usesTerm
    if (this.hasDueHintAutoTarget) this.dueHintAutoTarget.hidden = !usesTerm
  }

  toISODate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
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
