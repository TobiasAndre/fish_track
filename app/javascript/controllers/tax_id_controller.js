import { Controller } from "@hotwired/stimulus"

// Formats a CPF/CNPJ input as the user types: up to 11 digits mask as CPF
// (000.000.000-00), beyond that as CNPJ (00.000.000/0000-00).
export default class extends Controller {
  connect() {
    this.format()
  }

  format() {
    const digits = this.element.value.replace(/\D/g, "").slice(0, 14)
    this.element.value = digits.length > 11 ? this.maskCnpj(digits) : this.maskCpf(digits)
  }

  maskCpf(digits) {
    return digits
      .replace(/(\d{3})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d{1,2})$/, "$1-$2")
  }

  maskCnpj(digits) {
    return digits
      .replace(/(\d{2})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d)/, "$1.$2")
      .replace(/(\d{3})(\d)/, "$1/$2")
      .replace(/(\d{4})(\d{1,2})$/, "$1-$2")
  }
}
