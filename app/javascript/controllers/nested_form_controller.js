import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)

    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }

  remove(event) {
    event.preventDefault()

    const wrapper = event.currentTarget.closest("[data-nested-form-wrapper]")
    if (!wrapper) return

    const destroyInput = wrapper.querySelector('input[name*="[_destroy]"]')

    if (destroyInput) {
      destroyInput.value = "1"
      wrapper.classList.add("hidden")
    } else {
      wrapper.remove()
    }

    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
