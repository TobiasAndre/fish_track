import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    console.log("Theme controller connected")
    this.applyTheme()
  }

  toggle() {
    console.log("Toggling theme")
    const html = document.documentElement
    const isDark = html.classList.toggle("dark")

    localStorage.setItem("theme", isDark ? "dark" : "light")
    this.updateIcon(isDark)
  }

  applyTheme() {
    console.log("Applying saved or system theme")
    const savedTheme = localStorage.getItem("theme")
    const systemPrefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches

    const shouldBeDark = savedTheme ? savedTheme === "dark" : systemPrefersDark
    console.log("Should be dark:", shouldBeDark)
    document.documentElement.classList.toggle("dark", shouldBeDark)
    this.updateIcon(shouldBeDark)
  }

  updateIcon(isDark) {
    if (!this.hasIconTarget) return
    this.iconTarget.textContent = isDark ? "🌙" : "☀️"
  }
}