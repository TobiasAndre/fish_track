import { Controller } from "@hotwired/stimulus"

// Gráfico de linhas (Chartkick + Chart.js) a partir de dados no HTML. Substitui
// o <script> inline do helper line_chart, bloqueado pela CSP.
//   data-controller="chart"
//   data-chart-series-value='[["2026-09-01T08:00:00-03:00", 7.2], ...]'
//   data-chart-label-value="pH"  data-chart-color-value="#4f46e5"  data-chart-decimals-value="2"
export default class extends Controller {
  static values = {
    series: Array,
    label: String,
    color: String,
    decimals: { type: Number, default: 2 },
    suffix: String
  }

  // Eixo de tempo: definimos a unidade nós mesmos porque o Chartkick, quando escolhe
  // a unidade, formata os rótulos em inglês ("Sep 15, 8 AM").
  timeUnit() {
    const times = this.seriesValue.map(([time]) => new Date(time).getTime())
    const days = (Math.max(...times) - Math.min(...times)) / 86400000

    if (days <= 2) return "hour"
    if (days <= 150) return "day"
    return "month"
  }

  connect() {
    if (!window.Chartkick) return

    this.chart = new window.Chartkick.LineChart(this.element, [{ name: this.labelValue, data: this.seriesValue }], {
      colors: [this.colorValue || "#4f46e5"],
      curve: false,
      points: true,
      legend: false,
      round: this.decimalsValue,
      zeros: false,
      min: null,
      suffix: this.suffixValue ? ` ${this.suffixValue}` : null,
      height: "220px",
      library: {
        scales: {
          y: { beginAtZero: false, grace: "10%" },
          x: {
            time: {
              unit: this.timeUnit(),
              tooltipFormat: "dd/MM/yyyy HH:mm",
              displayFormats: { millisecond: "HH:mm:ss", second: "HH:mm:ss", minute: "HH:mm", hour: "dd/MM HH:mm", day: "dd/MM", week: "dd/MM", month: "MM/yyyy", year: "yyyy" }
            },
            ticks: { autoSkip: true, maxTicksLimit: 6, maxRotation: 0 }
          }
        },
        plugins: { tooltip: { intersect: false, mode: "index" } }
      }
    })
  }

  disconnect() {
    if (this.chart && typeof this.chart.destroy === "function") this.chart.destroy()
    this.chart = null
  }
}
