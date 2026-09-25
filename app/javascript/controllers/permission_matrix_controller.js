import { Controller } from "@hotwired/stimulus"

// Matriz de permissões (página x ação) do perfil de acesso.
//  - marcar Criar/Editar/Excluir marca Visualizar da mesma página (não se edita o que não se vê);
//  - desmarcar Visualizar desmarca as demais ações da página;
//  - a caixa da linha/coluna marca ou limpa tudo (com estado "parcial").
export default class extends Controller {
  static targets = ["box", "rowToggle", "columnToggle"]

  connect() {
    this.refreshToggles()
  }

  changed(event) {
    const box = event.currentTarget
    this.enforceReadDependency(box.dataset.resource, box)
    this.refreshToggles()
  }

  toggleRow(event) {
    const resource = event.currentTarget.dataset.resource
    this.boxesFor({ resource }).forEach((box) => (box.checked = event.currentTarget.checked))
    this.refreshToggles()
  }

  toggleColumn(event) {
    const action = event.currentTarget.dataset.column
    const boxes = this.boxesFor({ action })

    boxes.forEach((box) => (box.checked = event.currentTarget.checked))
    // Marcar uma coluna que não é a de leitura exige a leitura das mesmas páginas.
    boxes.forEach((box) => this.enforceReadDependency(box.dataset.resource, box))
    this.refreshToggles()
  }

  enforceReadDependency(resource, changedBox) {
    const readBox = this.boxesFor({ resource, action: "read" })[0]
    if (!readBox) return

    if (changedBox.dataset.actionName !== "read" && changedBox.checked) {
      readBox.checked = true
    } else if (changedBox.dataset.actionName === "read" && !changedBox.checked) {
      this.boxesFor({ resource }).forEach((box) => (box.checked = false))
    }
  }

  boxesFor({ resource, action }) {
    return this.boxTargets.filter(
      (box) => (!resource || box.dataset.resource === resource) && (!action || box.dataset.actionName === action)
    )
  }

  refreshToggles() {
    this.rowToggleTargets.forEach((toggle) => this.applyState(toggle, this.boxesFor({ resource: toggle.dataset.resource })))
    this.columnToggleTargets.forEach((toggle) => this.applyState(toggle, this.boxesFor({ action: toggle.dataset.column })))
  }

  applyState(toggle, boxes) {
    const checked = boxes.filter((box) => box.checked).length

    toggle.checked = boxes.length > 0 && checked === boxes.length
    toggle.indeterminate = checked > 0 && checked < boxes.length
  }
}
