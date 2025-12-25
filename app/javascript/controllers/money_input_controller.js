import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "cents"]

  connect() {
    // Se já tem valor em cents (edit), renderiza no input em reais
    const cents = this.centsTarget.value
    if (cents && cents !== "") {
      this.displayTarget.value = this.formatBRLFromCents(parseInt(cents, 10))
    }
  }

  input() {
    const cents = this.parseToCents(this.displayTarget.value)
    this.centsTarget.value = String(cents)
  }

  blur() {
    const cents = this.parseToCents(this.displayTarget.value)
    this.centsTarget.value = String(cents)
    this.displayTarget.value = this.formatBRLFromCents(cents)
  }

  // Converte string BRL em centavos (int)
  // Exemplos aceitos:
  // "200.000" -> 20000000
  // "200.000,50" -> 20000050
  // "200000,50" -> 20000050
  // "500000" -> 50000000
  parseToCents(raw) {
    if (!raw) return 0

    const s = String(raw).trim()

    // se tem vírgula, considera como separador decimal BR
    if (s.includes(",")) {
      const normalized = s.replace(/\./g, "").replace(",", ".") // remove milhar, vírgula->ponto
      const num = Number(normalized)
      if (Number.isNaN(num)) return 0
      return Math.round(num * 100)
    }

    // sem vírgula: pode ser "200.000" (milhar) ou "200000" (inteiro)
    const normalized = s.replace(/\./g, "")
    const num = Number(normalized)
    if (Number.isNaN(num)) return 0
    return Math.round(num * 100)
  }

  formatBRLFromCents(cents) {
    const value = (Number(cents) || 0) / 100
    return value.toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }
}
