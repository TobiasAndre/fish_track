import { Controller } from "@hotwired/stimulus"

// Página Backup: mostra o dia da semana só na frequência semanal e o dia do mês
// só na mensal.
export default class extends Controller {
  static targets = ["frequency", "weekday", "monthDay"]

  connect() {
    this.toggle()
  }

  toggle() {
    const frequency = this.frequencyTarget.value
    this.weekdayTarget.hidden = frequency !== "weekly"
    this.monthDayTarget.hidden = frequency !== "monthly"
  }
}
