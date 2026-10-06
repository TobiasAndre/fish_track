import { Controller } from "@hotwired/stimulus"
import { fieldBiometryStore } from "field_biometry_store"

// Na tela de login (após sair ou com a sessão expirada), apaga do aparelho os
// dados dos tanques da biometria em campo. As biometrias ainda não enviadas
// ficam guardadas para o próximo login.
export default class extends Controller {
  connect() {
    fieldBiometryStore.clearReference()
  }
}
