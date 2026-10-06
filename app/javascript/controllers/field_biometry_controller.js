import { Controller } from "@hotwired/stimulus"
import { fieldBiometryStore as store } from "field_biometry_store"

// Biometria em campo: lança biometrias sem internet e envia quando a conexão
// volta.
//
// Os tanques (com saldo e última biometria) são baixados com internet e ficam no
// aparelho. Cada biometria salva vai para uma fila local com um identificador
// próprio (uuid); o servidor usa esse identificador para nunca gravar a mesma
// biometria duas vezes, então reenviar é sempre seguro. Uma biometria só sai da
// fila quando o servidor confirma.
export default class extends Controller {
  static targets = [
    "company", "connection", "message", "referenceInfo", "refreshButton",
    "form", "formTitle", "tank", "tankInfo", "occurredOn", "volume", "quantity", "totalWeight", "feed", "notes",
    "previewList", "cancelEdit", "queueCount", "queueList", "syncButton", "sentCard", "sentList"
  ]

  static values = { dataUrl: String, syncUrl: String, loginUrl: String }

  connect() {
    this.editingUuid = null
    this.csrfToken = null
    this.readyOffline = false

    this.onOnline = () => {
      this.renderConnection()
      this.refresh({ quiet: true }).then(() => this.sync({ quiet: true }))
    }
    this.onOffline = () => this.renderConnection()
    this.onWorkerMessage = (event) => {
      if (event.data?.type === "field-page-cached") {
        this.readyOffline = true
        this.renderReference()
      }
    }

    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    navigator.serviceWorker?.addEventListener("message", this.onWorkerMessage)

    this.resetForm()
    this.renderAll()
    this.keepPageForOffline()
    navigator.storage?.persist?.().catch(() => {})

    if (navigator.onLine) this.refresh({ quiet: true }).then(() => this.sync({ quiet: true }))
  }

  disconnect() {
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
    navigator.serviceWorker?.removeEventListener("message", this.onWorkerMessage)
  }

  // ─── Tanques ────────────────────────────────────────────────────────────────

  async refresh(options = {}) {
    const quiet = options.quiet === true

    if (!navigator.onLine) {
      if (!quiet) this.showMessage("Sem internet: os tanques serão atualizados quando a conexão voltar.", "warning")
      return false
    }

    this.refreshButtonTarget.disabled = true

    try {
      const response = await fetch(this.dataUrlValue, {
        headers: { Accept: "application/json" }, credentials: "same-origin", cache: "no-store"
      })

      if (response.status === 401 || response.redirected) {
        this.sessionExpired()
        return false
      }

      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        this.showMessage(data.error || "Não foi possível atualizar os tanques.", "error")
        return false
      }

      const { csrf_token: csrfToken, ...reference } = data
      this.csrfToken = csrfToken
      store.saveReference(reference)
      this.renderAll()
      if (!quiet) this.showMessage("Tanques atualizados.", "success")
      return true
    } catch {
      if (!quiet) this.showMessage("Não foi possível falar com o servidor. Tente de novo com internet.", "error")
      return false
    } finally {
      this.refreshButtonTarget.disabled = false
    }
  }

  // ─── Lançamento ─────────────────────────────────────────────────────────────

  save(event) {
    event.preventDefault()

    const reference = store.reference()
    if (!reference) {
      this.showMessage("Baixe os tanques com internet antes de lançar (botão Atualizar tanques).", "error")
      return
    }

    const values = this.formValues()
    const errors = this.validate(values)
    if (errors.length) {
      this.showMessage(errors.join(" "), "error")
      return
    }

    const tank = this.findTank(values.batch_stocking_id)
    const queue = store.queue()
    const fields = { ...values, tank_label: tank ? this.tankLabel(tank) : `Tanque #${values.batch_stocking_id}`, error: null }

    if (this.editingUuid) {
      const index = queue.findIndex((entry) => entry.uuid === this.editingUuid)
      if (index >= 0) queue[index] = { ...queue[index], ...fields }
    } else {
      queue.push({
        uuid: this.newUuid(), tenant: reference.tenant, user_id: reference.user?.id,
        created_at: new Date().toISOString(), ...fields
      })
    }

    store.saveQueue(queue)
    const edited = Boolean(this.editingUuid)
    this.resetForm({ keepDate: true })
    this.renderQueue()
    this.showMessage(edited ? "Biometria alterada no aparelho." : "Biometria salva no aparelho. Ela será enviada quando houver internet.", "success")

    if (navigator.onLine) this.sync({ quiet: true })
  }

  edit(event) {
    const entry = store.queue().find((item) => item.uuid === event.params.uuid)
    if (!entry) return

    this.editingUuid = entry.uuid
    this.tankTarget.value = String(entry.batch_stocking_id)
    this.occurredOnTarget.value = entry.occurred_on
    this.volumeTarget.value = this.formatIntegerBR(entry.volume)
    this.quantityTarget.value = this.formatIntegerBR(entry.quantity)
    this.totalWeightTarget.value = this.formatDecimalInputValue(entry.total_weight_kg)
    this.feedTarget.value = this.formatDecimalInputValue(entry.feed_kg)
    this.notesTarget.value = entry.notes || ""
    this.formTitleTarget.textContent = "Editar biometria (ainda não enviada)"
    this.cancelEditTarget.hidden = false
    this.preview()
    this.formTarget.scrollIntoView({ behavior: "smooth" })
  }

  cancelEdit() {
    this.resetForm({ keepDate: true })
  }

  remove(event) {
    if (!window.confirm("Excluir esta biometria do aparelho? Ela não será enviada.")) return

    store.saveQueue(store.queue().filter((entry) => entry.uuid !== event.params.uuid))
    if (this.editingUuid === event.params.uuid) this.resetForm({ keepDate: true })
    this.renderQueue()
  }

  // ─── Envio ──────────────────────────────────────────────────────────────────

  async sync(options = {}) {
    const quiet = options.quiet === true
    if (this.syncing) return

    if (!this.sendableEntries().length) {
      if (!quiet) this.showMessage("Nenhuma biometria para enviar.", "info")
      return
    }

    if (!navigator.onLine) {
      if (!quiet) this.showMessage("Sem internet. As biometrias continuam salvas no aparelho.", "warning")
      return
    }

    this.syncing = true
    this.renderQueue()

    try {
      if (!this.csrfToken && !(await this.refresh({ quiet: true }))) return

      const entries = this.sendableEntries()
      if (!entries.length) return

      const response = await fetch(this.syncUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": this.csrfToken },
        body: JSON.stringify({ entries: entries.map((entry) => this.payload(entry)) })
      })

      if (response.status === 401 || response.redirected) {
        this.sessionExpired()
        return
      }

      if (response.status === 403) {
        this.showMessage("Seu perfil de acesso não permite lançar biometria.", "error")
        return
      }

      if (!response.ok) {
        this.csrfToken = null
        this.showMessage("O servidor não aceitou o envio. Nada foi perdido: tente de novo.", "error")
        return
      }

      const { results } = await response.json()
      this.applyResults(results || [])
    } catch {
      this.showMessage("A conexão caiu durante o envio. Nada foi perdido: tente de novo.", "error")
    } finally {
      this.syncing = false
      this.renderQueue()
    }
  }

  applyResults(results) {
    const byUuid = new Map(results.map((result) => [result.uuid, result]))
    const queue = store.queue()
    const sent = []
    const remaining = []

    queue.forEach((entry) => {
      const result = byUuid.get(entry.uuid)

      if (result && (result.status === "created" || result.status === "duplicate")) {
        sent.push({ ...entry, sent_at: new Date().toISOString() })
      } else if (result && result.status === "error") {
        remaining.push({ ...entry, error: (result.errors || []).join(" ") || "Não foi possível gravar." })
      } else {
        remaining.push(entry)
      }
    })

    store.saveQueue(remaining)
    if (sent.length) store.addSent(sent)
    this.renderSent()

    const failed = remaining.filter((entry) => entry.error).length
    const parts = []
    if (sent.length) parts.push(`${sent.length} biometria(s) enviada(s).`)
    if (failed) parts.push(`${failed} com problema: corrija ou exclua e envie de novo.`)
    if (parts.length) this.showMessage(parts.join(" "), failed ? "warning" : "success")
  }

  // Só as biometrias da empresa e do usuário logados neste aparelho.
  sendableEntries() {
    const reference = store.reference()
    if (!reference) return []

    return store.queue().filter((entry) => this.belongsTo(entry, reference))
  }

  belongsTo(entry, reference) {
    return reference && entry.tenant === reference.tenant && entry.user_id === reference.user?.id
  }

  payload(entry) {
    return {
      uuid: entry.uuid, tenant: entry.tenant, created_at: entry.created_at,
      batch_stocking_id: entry.batch_stocking_id, occurred_on: entry.occurred_on,
      volume: entry.volume, quantity: entry.quantity, total_weight_kg: entry.total_weight_kg,
      feed_kg: entry.feed_kg, notes: entry.notes
    }
  }

  sessionExpired() {
    this.csrfToken = null
    this.showMessage("Sua sessão expirou. Entre no sistema (com internet) para enviar as biometrias. Elas continuam salvas no aparelho.", "warning", {
      href: this.loginUrlValue, text: "Entrar"
    })
  }

  // ─── Guardar a tela para uso offline ────────────────────────────────────────

  // Pede ao service worker para guardar esta tela e todos os arquivos que ela
  // usa (CSS e módulos JS), para abrir sem internet já na próxima vez.
  async keepPageForOffline() {
    if (!("serviceWorker" in navigator) || !navigator.onLine) return

    const urls = new Set([window.location.pathname])
    document.querySelectorAll('link[rel="stylesheet"][href], link[rel="modulepreload"][href], script[src]').forEach((element) => {
      urls.add(element.href || element.src)
    })

    const importmap = document.querySelector('script[type="importmap"]')
    if (importmap) {
      try {
        Object.values(JSON.parse(importmap.textContent).imports || {}).forEach((url) => urls.add(new URL(url, window.location.href).href))
      } catch {}
    }

    try {
      const registration = await navigator.serviceWorker.ready
      registration.active?.postMessage({ type: "cache-field-page", urls: [...urls] })
    } catch {}
  }

  // ─── Prévia dos cálculos ────────────────────────────────────────────────────

  preview() {
    const tank = this.findTank(this.tankTarget.value)
    this.renderTankInfo(tank)

    const volume = this.parseNumber(this.volumeTarget.value)
    const quantity = this.parseNumber(this.quantityTarget.value)
    const totalWeight = this.parseNumber(this.totalWeightTarget.value)
    const feed = this.parseNumber(this.feedTarget.value)
    const last = tank?.last_biometry

    const avgWeight = quantity > 0 && totalWeight > 0 ? (totalWeight / quantity) * 1000 : 0
    const biomass = volume > 0 && avgWeight > 0 ? volume * avgWeight / 1000 : 0
    const gain = biomass > 0 && last?.biomass ? biomass - last.biomass : null
    const days = last?.occurred_on ? this.daysBetween(last.occurred_on, this.occurredOnTarget.value) : 0
    const gpd = avgWeight > 0 && last?.avg_weight_g && days > 0 ? (avgWeight - last.avg_weight_g) / days : null
    const conversion = feed > 0 && gain > 0 ? feed / gain : null

    const rows = [
      ["Peso médio (g)", avgWeight > 0 ? this.formatDecimalBR(avgWeight) : "—"],
      ["Biomassa (kg)", biomass > 0 ? this.formatDecimalBR(biomass) : "—"],
      ["Ganho de peso (kg)", gain !== null ? this.formatDecimalBR(gain) : "—"],
      ["GPD (g/dia)", gpd !== null ? this.formatDecimalBR(gpd) : "—"],
      ["Conversão alimentar", conversion !== null ? this.formatDecimalBR(conversion) : "—"]
    ]

    this.previewListTarget.replaceChildren(...rows.flatMap(([label, value]) => [
      this.element_("dt", "text-gray-500 dark:text-gray-400", label),
      this.element_("dd", "text-right font-medium", value)
    ]))
  }

  formatInteger(event) {
    event.target.value = this.formatIntegerBR(event.target.value)
    this.preview()
  }

  formatDecimal(event) {
    event.target.value = this.normalizeDecimalTyping(event.target.value)
    this.preview()
  }

  // ─── Formulário ─────────────────────────────────────────────────────────────

  formValues() {
    const decimal = (value) => {
      const number = this.parseNumber(value)
      return number > 0 ? String(number) : ""
    }

    return {
      batch_stocking_id: Number(this.tankTarget.value) || null,
      occurred_on: this.occurredOnTarget.value,
      volume: String(Math.round(this.parseNumber(this.volumeTarget.value)) || ""),
      quantity: String(Math.round(this.parseNumber(this.quantityTarget.value)) || ""),
      total_weight_kg: decimal(this.totalWeightTarget.value),
      feed_kg: decimal(this.feedTarget.value),
      notes: this.notesTarget.value.trim()
    }
  }

  validate(values) {
    const errors = []
    if (!values.batch_stocking_id) errors.push("Escolha o tanque.")
    if (!values.occurred_on) errors.push("Informe a data.")
    if (!(Number(values.volume) > 0)) errors.push("Informe o volume.")
    if (!(Number(values.quantity) > 0)) errors.push("Informe a quantidade.")
    if (!(Number(values.total_weight_kg) > 0)) errors.push("Informe o peso.")
    return errors
  }

  resetForm(options = {}) {
    const date = options.keepDate && this.occurredOnTarget.value ? this.occurredOnTarget.value : this.today()
    const tank = this.tankTarget.value

    this.formTarget.reset()
    this.editingUuid = null
    this.occurredOnTarget.value = date
    if (options.keepDate) this.tankTarget.value = tank
    this.formTitleTarget.textContent = "Nova biometria"
    this.cancelEditTarget.hidden = true
    this.preview()
  }

  // ─── Renderização ───────────────────────────────────────────────────────────

  renderAll() {
    this.renderConnection()
    this.renderReference()
    this.renderTankOptions()
    this.renderQueue()
    this.renderSent()
    this.preview()
  }

  renderConnection() {
    const online = navigator.onLine
    this.connectionTarget.textContent = online ? "Com internet" : "Sem internet"
    this.connectionTarget.className = `shrink-0 rounded-full px-3 py-1 text-xs font-medium ${online
      ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200"
      : "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-200"}`
    this.refreshButtonTarget.disabled = !online
  }

  renderReference() {
    const reference = store.reference()

    if (!reference) {
      this.companyTarget.textContent = ""
      this.referenceInfoTarget.textContent = navigator.onLine
        ? "Baixando os tanques…"
        : "Nenhum tanque neste aparelho. Abra esta tela com internet (logado) para baixar os tanques."
      return
    }

    this.companyTarget.textContent = [reference.company_name, reference.user?.name].filter(Boolean).join(" · ")

    const updatedAt = this.referenceTime(reference)
    const count = (reference.batch_stockings || []).length
    const ready = this.readyOffline ? " Esta tela já abre sem internet neste aparelho." : ""
    const stale = this.referenceIsStale(reference)
      ? " Atenção: dados com mais de 1 dia. O saldo dos tanques pode ter mudado (mortalidade, carregamento) e lotes novos não aparecem; atualize com internet assim que puder."
      : ""

    this.referenceInfoTarget.textContent = `${count} tanque(s) de lotes ativos, atualizados em ${updatedAt}.${ready}${stale}`
    this.referenceInfoTarget.className = stale ? "text-amber-700 dark:text-amber-300" : "text-gray-600 dark:text-gray-300"
  }

  referenceTime(reference) {
    return reference?.generated_at ? new Date(reference.generated_at).toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" }) : "—"
  }

  referenceIsStale(reference) {
    if (!reference?.generated_at) return false
    return Date.now() - new Date(reference.generated_at).getTime() > 24 * 60 * 60 * 1000
  }

  renderTankOptions() {
    const reference = store.reference()
    const selected = this.tankTarget.value
    const tanks = reference?.batch_stockings || []

    const placeholder = this.element_("option", "", tanks.length ? "Escolha o tanque" : "Nenhum tanque baixado")
    placeholder.value = ""

    const groups = new Map()
    tanks.forEach((tank) => {
      if (!groups.has(tank.unit)) groups.set(tank.unit, [])
      groups.get(tank.unit).push(tank)
    })

    const optgroups = [...groups.entries()].map(([unit, unitTanks]) => {
      const group = document.createElement("optgroup")
      group.label = unit
      unitTanks.forEach((tank) => {
        const option = this.element_("option", "", `${tank.pond} — Lote ${tank.batch}`)
        option.value = String(tank.id)
        group.appendChild(option)
      })
      return group
    })

    this.tankTarget.replaceChildren(placeholder, ...optgroups)
    if (selected && tanks.some((tank) => String(tank.id) === selected)) this.tankTarget.value = selected
  }

  renderTankInfo(tank) {
    if (!tank) {
      this.tankInfoTarget.textContent = ""
      return
    }

    const parts = []
    if (tank.current_quantity != null) {
      parts.push(`Saldo em ${this.referenceTime(store.reference())}: ${this.formatIntegerBR(tank.current_quantity)} peixes`)
    }
    const last = tank.last_biometry
    parts.push(last
      ? `Última biometria: ${this.formatDate(last.occurred_on)} (peso médio ${this.formatDecimalBR(last.avg_weight_g || 0)} g)`
      : "Sem biometria anterior")
    this.tankInfoTarget.textContent = parts.join(" · ")
  }

  renderQueue() {
    const reference = store.reference()
    const queue = store.queue()

    this.queueCountTarget.textContent = queue.length ? `(${queue.length})` : ""
    this.syncButtonTarget.disabled = this.syncing || !navigator.onLine || !this.sendableEntries().length
    this.syncButtonTarget.textContent = this.syncing ? "Enviando…" : "Enviar agora"

    if (!queue.length) {
      this.queueListTarget.replaceChildren(this.element_("li", "py-2 text-sm text-gray-500 dark:text-gray-400", "Nenhuma biometria aguardando envio."))
      return
    }

    this.queueListTarget.replaceChildren(...queue.map((entry) => {
      const item = this.element_("li", "py-3 space-y-1")
      item.appendChild(this.element_("p", "text-sm font-medium", entry.tank_label))
      item.appendChild(this.element_("p", "text-xs text-gray-500 dark:text-gray-400",
        `${this.formatDate(entry.occurred_on)} · Qtd ${this.formatIntegerBR(entry.quantity)} · Peso ${this.formatDecimalBR(Number(entry.total_weight_kg))} kg · Volume ${this.formatIntegerBR(entry.volume)}`))

      if (!this.belongsTo(entry, reference)) {
        item.appendChild(this.element_("p", "text-xs text-amber-700 dark:text-amber-300",
          reference ? "Lançada por outro usuário ou em outra empresa: entre com a conta que lançou para enviar." : "Entre no sistema com internet para enviar."))
      } else if (entry.error) {
        item.appendChild(this.element_("p", "text-xs text-red-700 dark:text-red-300", `Não foi gravada: ${entry.error}`))
      } else {
        item.appendChild(this.element_("p", "text-xs text-gray-500 dark:text-gray-400", "Aguardando envio"))
      }

      const actions = this.element_("div", "flex gap-3 pt-1")
      const editButton = this.element_("button", "text-sm text-indigo-600 dark:text-indigo-400", "Editar")
      editButton.type = "button"
      editButton.dataset.action = "field-biometry#edit"
      editButton.dataset.fieldBiometryUuidParam = entry.uuid
      const removeButton = this.element_("button", "text-sm text-red-600 dark:text-red-400", "Excluir")
      removeButton.type = "button"
      removeButton.dataset.action = "field-biometry#remove"
      removeButton.dataset.fieldBiometryUuidParam = entry.uuid
      actions.append(editButton, removeButton)
      item.appendChild(actions)

      return item
    }))
  }

  renderSent() {
    const sent = store.sent()
    this.sentCardTarget.hidden = !sent.length

    this.sentListTarget.replaceChildren(...sent.slice(0, 10).map((entry) => this.element_("li", "py-2",
      `${entry.tank_label} · ${this.formatDate(entry.occurred_on)} · enviada em ${new Date(entry.sent_at).toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" })}`)))
  }

  showMessage(text, kind = "info", link = null) {
    const styles = {
      success: "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-200",
      error: "border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300",
      warning: "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-200",
      info: "border-gray-200 bg-white text-gray-700 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-300"
    }

    this.messageTarget.className = `rounded-lg border px-3 py-2 text-sm ${styles[kind] || styles.info}`
    this.messageTarget.replaceChildren(document.createTextNode(text))

    if (link) {
      const anchor = this.element_("a", "ml-2 font-medium underline", link.text)
      anchor.href = link.href
      anchor.dataset.turbo = "false"
      this.messageTarget.appendChild(anchor)
    }

    this.messageTarget.hidden = false
  }

  // ─── Utilitários ────────────────────────────────────────────────────────────

  findTank(id) {
    return (store.reference()?.batch_stockings || []).find((tank) => String(tank.id) === String(id))
  }

  tankLabel(tank) {
    return `${tank.unit} • ${tank.pond} • Lote ${tank.batch}`
  }

  element_(tag, className = "", text = null) {
    const element = document.createElement(tag)
    if (className) element.className = className
    if (text !== null) element.textContent = text
    return element
  }

  newUuid() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()

    const bytes = window.crypto.getRandomValues(new Uint8Array(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("")
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }

  today() {
    const now = new Date()
    return [now.getFullYear(), String(now.getMonth() + 1).padStart(2, "0"), String(now.getDate()).padStart(2, "0")].join("-")
  }

  formatDate(isoDate) {
    if (!isoDate) return "—"
    const [year, month, day] = isoDate.split("-")
    return `${day}/${month}/${year}`
  }

  daysBetween(start, end) {
    if (!start || !end) return 0
    const days = Math.round((new Date(`${end}T00:00:00`) - new Date(`${start}T00:00:00`)) / 86400000)
    return days > 0 ? days : 0
  }

  // "1.234,5" -> 1234.5 ; "12.5" -> 12.5
  parseNumber(value) {
    const text = String(value ?? "").trim()
    if (!text) return 0
    const normalized = text.includes(",") ? text.replace(/\./g, "").replace(",", ".") : text.replace(/\.(?=\d{3}(\D|$))/g, "")
    const number = parseFloat(normalized)
    return Number.isFinite(number) ? number : 0
  }

  formatIntegerBR(value) {
    const digits = String(value ?? "").replace(/\D/g, "")
    return digits ? digits.replace(/\B(?=(\d{3})+(?!\d))/g, ".") : ""
  }

  normalizeDecimalTyping(value) {
    let cleaned = String(value || "").replace(/[^\d,]/g, "")
    if (!cleaned) return ""

    const comma = cleaned.indexOf(",")
    if (comma !== -1) cleaned = cleaned.slice(0, comma + 1) + cleaned.slice(comma + 1).replace(/,/g, "")

    const [integerPart, decimals] = cleaned.split(",")
    const integer = this.formatIntegerBR(integerPart.replace(/^0+(?=\d)/, "") || "0")
    return decimals !== undefined ? `${integer},${decimals.slice(0, 3)}` : integer
  }

  formatDecimalInputValue(value) {
    const number = Number(value)
    if (!(number > 0)) return ""
    return this.normalizeDecimalTyping(String(number).replace(".", ","))
  }

  formatDecimalBR(number, precision = 3) {
    return new Intl.NumberFormat("pt-BR", { minimumFractionDigits: precision, maximumFractionDigits: precision }).format(number)
  }
}
