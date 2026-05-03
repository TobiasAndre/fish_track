import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "mobileDrawer", "label", "collapseIcon"]

  connect() {
    const collapsed = localStorage.getItem("sidebar:collapsed") === "true"
    this.setCollapsed(collapsed)

    this.closeMobile()
  }

  toggleCollapse() {
    const isCollapsed = this.sidebarTarget.classList.contains("w-20")
    this.setCollapsed(!isCollapsed)
  }

  setCollapsed(collapsed) {
    this.sidebarTarget.classList.toggle("w-64", !collapsed)
    this.sidebarTarget.classList.toggle("w-20", collapsed)

    this.labelTargets.forEach((el) => el.classList.toggle("hidden", collapsed))

    if (this.hasCollapseIconTarget) {
      this.collapseIconTarget.classList.toggle("rotate-180", collapsed)
    }

    localStorage.setItem("sidebar:collapsed", collapsed ? "true" : "false")
  }

  openMobile() {
    if (!this.hasOverlayTarget || !this.hasMobileDrawerTarget) return

    this.overlayTarget.classList.remove("hidden")
    this.mobileDrawerTarget.dataset.open = "true"
    document.body.classList.add("overflow-hidden")
  }

  closeMobile() {
    if (!this.hasOverlayTarget || !this.hasMobileDrawerTarget) return

    this.mobileDrawerTarget.dataset.open = "false"
    document.body.classList.remove("overflow-hidden")

    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
    }, 200)
  }

  toggleMobile() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.contains("hidden")
      ? this.openMobile()
      : this.closeMobile()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.closeMobile()
  }
}
