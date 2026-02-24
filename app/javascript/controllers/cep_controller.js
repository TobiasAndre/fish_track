import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cep", "street", "neighborhood", "city", "state", "error", "loading"]
  static values = { url: String }

  connect() {
    this._lastCep = null
  }

  onCepInput() {
    const raw = this.cepTarget.value || ""
    const digits = raw.replace(/\D/g, "").slice(0, 8)

    // Máscara 00000-000
    const masked = digits.length > 5 ? `${digits.slice(0, 5)}-${digits.slice(5)}` : digits
    if (masked !== raw) this.cepTarget.value = masked

    // Se ainda não tem 8 dígitos, libera nova consulta e limpa erro
    if (digits.length < 8) {
      this._lastCep = null
      this._clearError()
      return
    }

    // Completou 8 dígitos -> busca
    this.lookup()
  }

  async lookup() {
    this._clearError()

    const digits = (this.cepTarget.value || "").replace(/\D/g, "")
    if (digits.length !== 8) return

    // evita refetch do mesmo CEP já consultado com sucesso
    if (digits === this._lastCep) return

    try {
      this._setLoading(true)

      const urlTemplate = this.urlValue || "https://viacep.com.br/ws/%{cep}/json/"
      const url = urlTemplate.replace("%{cep}", digits)

      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) throw new Error("Falha ao consultar o CEP")

      const data = await res.json()
      if (data.erro) {
        this._showError("CEP não encontrado.")
        return
      }

      this._setValue(this.streetTarget, data.logradouro)
      this._setValue(this.neighborhoodTarget, data.bairro)
      this._setValue(this.cityTarget, data.localidade)
      this._setValue(this.stateTarget, data.uf)

      this._lastCep = digits

      const numberField = this.element.querySelector(
        '[name$="[address_number]"], [name="customer[address_number]"], [name="supplier[address_number]"]'
      )
      if (numberField) numberField.focus()
    } catch (e) {
      this._showError("Não foi possível consultar o CEP. Tente novamente.")
    } finally {
      this._setLoading(false)
    }
  }

  _setValue(input, value) {
    if (!input) return
    input.value = value || ""
    input.dispatchEvent(new Event("input", { bubbles: true }))
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