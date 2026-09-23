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
    "loadingCostCents",
    "taxPercentage",
    "grandTotal",
    "totalCents",
    "occurredOn",
    "paymentTerm",
    "paymentDate",
    "dueHintManual"
  ]

  connect() {
    console.log("LoadingFormController connected")
    this.formatInitialCurrencyValues()
    this.recalculate()
    this.applyDueDate()
  }

  // Com uma condição de pagamento, o vencimento é a data do lançamento + dias
  // da 1ª parcela e o campo fica somente leitura; sem condição, é manual.
  applyDueDate() {
    if (!this.hasPaymentDateTarget || !this.hasPaymentTermTarget || !this.hasOccurredOnTarget) return

    const option = this.paymentTermTarget.options[this.paymentTermTarget.selectedIndex]
    const offset = option ? parseInt(option.dataset.firstOffset ?? "", 10) : NaN
    const baseDate = this.occurredOnTarget.value
    const usesTerm = Boolean(this.paymentTermTarget.value) && !Number.isNaN(offset) && Boolean(baseDate)

    if (usesTerm) {
      const [year, month, day] = baseDate.split("-").map(Number)
      const date = new Date(year, month - 1, day + offset)
      const pad = (n) => String(n).padStart(2, "0")
      this.paymentDateTarget.value = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
    }

    this.paymentDateTarget.readOnly = usesTerm
    this.paymentDateTarget.classList.toggle("bg-gray-50", usesTerm)
    this.paymentDateTarget.classList.toggle("dark:bg-gray-900", usesTerm)

    if (this.hasDueHintManualTarget) this.dueHintManualTarget.hidden = usesTerm
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

  formatDigitsOnlyInput(event) {
    event.currentTarget.value = event.currentTarget.value.replace(/\D/g, "")
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

    this.recalculateTotal(totalWeightKg, quantity)
  }

  recalculateTotal(totalWeightKg, quantity) {
    const pricePerKgCents = this.hasPricePerKgCentsTarget ? Number(this.pricePerKgCentsTarget.value || 0) : 0
    const thousandValueCents = this.hasThousandValueCentsTarget ? Number(this.thousandValueCentsTarget.value || 0) : 0
    const loadingCostCents = this.hasLoadingCostCentsTarget ? Number(this.loadingCostCentsTarget.value || 0) : 0
    const freightCostCents = this.hasFreightCostCentsTarget ? Number(this.freightCostCentsTarget.value || 0) : 0

    const taxPercentage = this.hasTaxPercentageTarget ? this.parseLocalizedNumber(this.taxPercentageTarget.value) : 0

    const fishTotalCents =
      (totalWeightKg * pricePerKgCents) + (thousandValueCents * (quantity / 1000))

    const subtotalCents = fishTotalCents + loadingCostCents + freightCostCents
    const taxCents = subtotalCents * (taxPercentage / 100)

    const grandTotalCents = Math.round(subtotalCents + taxCents)

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.formatCurrency(grandTotalCents / 100)
    }

    if (this.hasTotalCentsTarget) {
      this.totalCentsTarget.value = grandTotalCents
    }
  }

  maskCurrency(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "")

    if (!digits) {
      input.value = ""
      this.syncCurrencyHiddenTarget(input, 0)
      this.recalculate()
      return
    }

    const cents = Number(digits)
    input.value = this.formatCurrency(cents / 100)
    this.moveCursorToEnd(input)

    this.syncCurrencyHiddenTarget(input, cents)
    this.recalculate()
  }

  // Currency fields accumulate digits from the full displayed text on every
  // keystroke. If the cursor is left in the middle of a pre-filled value
  // (common when editing an existing record), typing there inserts a digit
  // mid-string and inflates the parsed amount by 10x or more. Forcing the
  // cursor to the end on focus and after every reformat keeps typing
  // append-only, so it always matches what's displayed.
  focusCurrencyEnd(event) {
    this.moveCursorToEnd(event.currentTarget)
  }

  moveCursorToEnd(input) {
    const length = input.value.length
    input.setSelectionRange(length, length)
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

    const stringValue = String(value).trim()
    if (!stringValue) return 0

    // Only treat "." as a thousands separator when a "," is also present
    // (pt-BR format, e.g. "1.234,56"). Otherwise this is a plain decimal
    // string (e.g. "1000.0", as rendered straight from a BigDecimal), so the
    // "." must be kept as the decimal point instead of stripped.
    const normalized = stringValue.includes(",")
      ? stringValue.replace(/\./g, "").replace(",", ".")
      : stringValue

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
