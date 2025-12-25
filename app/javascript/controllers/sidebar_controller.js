import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "label", "collapseIcon"]

  connect() {
    // restore collapsed state (desktop)
    const collapsed = localStorage.getItem("sidebar:collapsed") === "true"
    this.setCollapsed(collapsed)

    // start closed on mobile
    this.closeMobile()
  }

  toggleCollapse() {
    const isCollapsed = this.sidebarTarget.classList.contains("w-20")
    this.setCollapsed(!isCollapsed)
  }

  setCollapsed(collapsed) {
    // Width
    this.sidebarTarget.classList.toggle("w-64", !collapsed)
    this.sidebarTarget.classList.toggle("w-20", collapsed)

    // Hide labels when collapsed
    this.labelTargets.forEach((el) => el.classList.toggle("hidden", collapsed))

    // Rotate icon
    if (this.hasCollapseIconTarget) {
      this.collapseIconTarget.classList.toggle("rotate-180", collapsed)
    }

    localStorage.setItem("sidebar:collapsed", collapsed ? "true" : "false")
  }

  openMobile() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  closeMobile() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  toggleMobile() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.contains("hidden") ? this.openMobile() : this.closeMobile()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.closeMobile()
  }
}