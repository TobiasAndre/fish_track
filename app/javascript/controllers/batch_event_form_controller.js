import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "type",
    "biometryRow",
    "feedKgRow",
    "quantity",
    "totalWeight",
    "volume",
    "avgWeight",
    "biomass",
    "weightGain",
    "gpd",
    "previousBiomass",
    "previousAvgWeight",
    "previousOccurredOn",
    "occurredOn",
    "mortalityRow",
    "mortalityQuantity",
    "mortalityAvgWeight",
    "mortalityWeightLoss",
    "currentAvgWeight"
  ]

  connect() {
    this.toggle()
    this.formatInitialValues()
    this.recalculate()
  }

  toggle() {
    const eventType = this.typeTarget.value
    const isBiometry = this.isBiometryEvent(eventType)
    const isFeeding = eventType === "feeding"
    const isMortality = eventType === "mortality"

    console.log("Toggling form for event type:", eventType)

    this.toggleTarget("biometryRow", isBiometry)
    this.toggleTarget("feedKgRow", isFeeding)
    this.toggleTarget("mortalityRow", isMortality)

    if (!isBiometry) {
      this.clearBiometryFields()
      return
    }

    if (isMortality) {
      this.recalculateMortality()
    }

    this.recalculate()
  }

  parseStoredNumber(value) {
    if (value == null || value === "") return 0

    const parsed = Number(String(value).trim())
    return Number.isNaN(parsed) ? 0 : parsed
  }

  recalculate() {
    if (!this.hasTypeTarget || !this.isBiometryEvent(this.typeTarget.value)) return

    const quantity = this.parseNumber(this.hasQuantityTarget ? this.quantityTarget.value : "")
    const totalWeightKg = this.parseNumber(this.hasTotalWeightTarget ? this.totalWeightTarget.value : "")
    const volume = this.parseNumber(this.hasVolumeTarget ? this.volumeTarget.value : "")
    const previousBiomass = this.parseStoredNumber(this.hasPreviousBiomassTarget ? this.previousBiomassTarget.value : "")
    const previousAvgWeight = this.parseStoredNumber(this.hasPreviousAvgWeightTarget ? this.previousAvgWeightTarget.value : "")
    const previousOccurredOn = this.hasPreviousOccurredOnTarget ? this.previousOccurredOnTarget.value : ""
    const currentOccurredOn = this.hasOccurredOnTarget ? this.occurredOnTarget.value : ""

    console.log("Recalculating with values:", {
      quantity,
      totalWeightKg,
      volume,
      previousBiomass,
      previousAvgWeight,
      previousOccurredOn,
      currentOccurredOn
    })

    let avgWeightG = 0
    let biomass = 0
    let weightGainKg = 0
    let gpd = 0

    if (quantity > 0 && totalWeightKg > 0) {
      avgWeightG = (totalWeightKg / quantity) * 1000
    }

    if (volume > 0 && avgWeightG > 0) {
      biomass = volume * (avgWeightG / 1000)
    }

    // ganho = biomassa atual - biomassa anterior
    if (biomass > 0) {
      weightGainKg = biomass - previousBiomass
    }

    const daysDiff = this.daysBetween(previousOccurredOn, currentOccurredOn)
    if (daysDiff > 0 && avgWeightG > 0 && previousAvgWeight > 0) {
      gpd = (avgWeightG - previousAvgWeight) / daysDiff
    }

    if (this.hasAvgWeightTarget) {
      this.avgWeightTarget.value = avgWeightG > 0 ? this.formatDecimal(avgWeightG, 2) : ""
    }

    if (this.hasBiomassTarget) {
      this.biomassTarget.value = biomass > 0 ? this.formatDecimal(biomass, 2) : ""
    }

    if (this.hasWeightGainTarget) {
      this.weightGainTarget.value = this.formatDecimal(weightGainKg, 2)
    }

    if (this.hasGpdTarget) {
      this.gpdTarget.value = this.formatDecimal(gpd, 3)
    }
  }

  recalculateMortality() {
    if (!this.hasMortalityQuantityTarget || !this.hasCurrentAvgWeightTarget) return

    const quantity = this.parseNumber(this.mortalityQuantityTarget.value)
    const avgWeight = this.parseStoredNumber(this.currentAvgWeightTarget.value)

    const totalWeightKg = quantity > 0 && avgWeight > 0
      ? (quantity * avgWeight) / 1000
      : 0

    if (this.hasMortalityAvgWeightTarget) {
      this.mortalityAvgWeightTarget.value = this.formatDecimal(avgWeight, 2)
    }

    if (this.hasMortalityWeightLossTarget) {
      this.mortalityWeightLossTarget.value = this.formatDecimal(totalWeightKg, 3)
    }
  }

  formatMortalityQuantityInput(event) {
    let value = event.target.value.replace(/\D/g, "")

    if (!value) {
      event.target.value = ""
      this.recalculateMortality()
      return
    }

    event.target.value = this.formatWithDelimiter(value)
    this.recalculateMortality()
  }

  formatIntegerInput(event) {
    let value = event.target.value.replace(/\D/g, "")

    if (!value) {
      event.target.value = ""
      this.recalculate()
      return
    }

    event.target.value = this.formatWithDelimiter(value)
    this.recalculate()
  }

  formatDecimalInput(event) {
    let value = event.target.value

    if (!value) {
      this.recalculate()
      return
    }

    value = value.replace(/[^0-9,\.]/g, "")

    const parts = value.split(/[,.]/)
    if (parts.length > 2) {
      value = parts[0] + "," + parts[1]
    }

    event.target.value = value
    this.recalculate()
  }

  toggleTarget(targetName, show) {
    const targetProperty = `has${this.capitalize(targetName)}Target`
    const elementProperty = `${targetName}Target`

    if (!this[targetProperty]) return

    this[elementProperty].classList.toggle("hidden", !show)
  }

  clearBiometryFields() {
    if (this.hasAvgWeightTarget) this.avgWeightTarget.value = ""
    if (this.hasBiomassTarget) this.biomassTarget.value = ""
    if (this.hasWeightGainTarget) this.weightGainTarget.value = this.formatDecimal(0, 2)
    if (this.hasGpdTarget) this.gpdTarget.value = this.formatDecimal(0, 3)
  }

  formatInitialValues() {
    if (this.hasVolumeTarget) {
      const rawValue = this.volumeTarget.value
      const volume = Number(rawValue)

      this.volumeTarget.value =
        !Number.isNaN(volume) && volume > 0
          ? this.formatInteger(volume)
          : ""
    }

    if (this.hasTotalWeightTarget) {
      const rawValue = this.totalWeightTarget.value
      const totalWeight = Number(rawValue)

      this.totalWeightTarget.value =
        !Number.isNaN(totalWeight) && totalWeight > 0
          ? this.formatDecimal(totalWeight, 3)
          : ""
    }

    this.recalculate()
  }

  parseNumber(value) {
    if (value == null || value === "") return 0

    const normalized = String(value).trim().replace(/\./g, "").replace(",", ".")
    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  formatDecimal(value, decimals = 2) {
    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    }).format(Number(value || 0))
  }

  formatInteger(value) {
    return String(Math.round(Number(value || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  formatWithDelimiter(value) {
    return value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  daysBetween(startDate, endDate) {
    if (!startDate || !endDate) return 0

    const start = new Date(startDate + "T00:00:00")
    const end = new Date(endDate + "T00:00:00")

    if (isNaN(start) || isNaN(end)) return 0

    const diffMs = end - start
    return Math.round(diffMs / (1000 * 60 * 60 * 24))
  }

  isBiometryEvent(eventType) {
    return eventType === "biometrics" || eventType === "biometry"
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }
}
