import { Controller } from "@hotwired/stimulus"

// Submits the controller's form on a field's "change" event. Replaces
// inline onchange="this.form.submit()" attributes, which the app's
// Content-Security-Policy (script-src, no unsafe-inline/unsafe-hashes)
// silently blocks.
export default class extends Controller {
  submit() {
    this.requestSubmit()
  }

  // Clears a dependent field (e.g. a pond select) before submitting, for
  // filters where changing the parent field invalidates the child's value.
  // Usage: data: { action: "change->auto-submit#resetFieldAndSubmit", reset_field_id: "pond_id" }
  resetFieldAndSubmit(event) {
    const fieldId = event.target.dataset.resetFieldId
    const field = fieldId && document.getElementById(fieldId)
    if (field) field.value = ""

    this.requestSubmit()
  }

  requestSubmit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
