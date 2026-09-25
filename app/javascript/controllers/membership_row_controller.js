import { Controller } from "@hotwired/stimulus"

// Linha "empresa" do formulário de usuário: os campos de tipo e de perfil só
// ficam ativos com o acesso marcado, e o perfil só vale para o tipo "Membro"
// (proprietários e administradores enxergam tudo).
export default class extends Controller {
  static targets = ["enabled", "role", "profile", "profileWrapper", "details"]

  connect() {
    this.refresh()
  }

  refresh() {
    const enabled = this.enabledTarget.checked
    const member = this.roleTarget.value === "member"

    this.detailsTarget.classList.toggle("hidden", !enabled)
    this.roleTarget.disabled = !enabled
    this.profileTarget.disabled = !enabled || !member
    this.profileWrapperTarget.classList.toggle("hidden", !member)
  }
}
