import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cep", "street", "neighborhood", "city", "state", "error", "loading"]
  static values = {
    url: String,
  }

  connect() {
    this._lastCep = null
  }

  onCepInput() {
    const raw = this.cepTarget.value || ""
    const digits = raw.replace(/\D/g, "").slice(0, 8)

    // Máscara simples 00000-000
    const masked = digits.length > 5 ? `${digits.slice(0, 5)}-${digits.slice(5)}` : digits
    if (masked !== raw) this.cepTarget.value = masked

    // Se completou 8 dígitos, busca automático
    if (digits.length === 8) this.lookup()
  }

  async lookup() {
    this._clearError()

    const digits = (this.cepTarget.value || "").replace(/\D/g, "")
    if (digits.length !== 8) return

    // evita buscar o mesmo CEP repetido
    if (digits === this._lastCep) return
    this._lastCep = digits

    try {
      this._setLoading(true)

      const urlTemplate = this.urlValue || "https://viacep.com.br/ws/%{cep}/json/"
      const url = urlTemplate.replace("%{cep}", digits)

      const res = await fetch(url, { headers: { "Accept": "application/json" } })
      if (!res.ok) throw new Error("Falha ao consultar o CEP")

      const data = await res.json()
      if (data.erro) {
        this._showError("CEP não encontrado.")
        return
      }

      // Preenche campos (sem sobrescrever se o usuário já digitou algo manualmente)
      this._fillIfEmpty(this.streetTarget, data.logradouro)
      this._fillIfEmpty(this.neighborhoodTarget, data.bairro)
      this._fillIfEmpty(this.cityTarget, data.localidade)
      this._fillIfEmpty(this.stateTarget, data.uf)

      // Foca no número depois de preencher (se existir no DOM)
      const numberField = this.element.querySelector('[name$="[address_number]"], [name="customer[address_number]"], [name="supplier[address_number]"]')
      if (numberField) numberField.focus()
    } catch (e) {
      this._showError("Não foi possível consultar o CEP. Tente novamente.")
    } finally {
      this._setLoading(false)
    }
  }

  _fillIfEmpty(input, value) {
    if (!input) return
    const current = (input.value || "").trim()
    if (current.length === 0 && value) input.value = value
  }

  _setLoading(on) {
    if (!this.hasLoadingTarget) return
    this.loadingTarget.classList.toggle("hidden", !on)
  }

  _showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  _clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
