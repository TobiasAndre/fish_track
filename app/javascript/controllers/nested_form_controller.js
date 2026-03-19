import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  connect() {
    console.log("NestedFormController connected")
  }

  add(event) {
    console.log("Adding nested form item...")
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    console.log("Removing nested form item...")
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
  }
}
