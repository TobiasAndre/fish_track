import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "type",
    "occurredOn",

    "biometryRow",
    "mortalityRow",
    "feedKgRow",
    "loadingRow",

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

    "currentAvgWeight",
    "mortalityQuantity",
    "mortalityAvgWeight",
    "mortalityWeightLoss",

    "pricePerKg",
    "pricePerKgCents",
    "thousandValue",
    "thousandValueCents",
    "freightCost",
    "freightCostCents",
    "loadingCost",
    "loadingCostCents",

    "loadingQuantity",
    "loadingTotalWeight",
    "loadingAvgWeight",

    "feedKgBiometry",
    "feedConversion"
  ]

  connect() {
    console.log("BatchEventFormController connected")
    this.toggle()
    this.formatInitialValues()
    this.recalculate()
    this.recalculateMortality()
    this.recalculateLoading()
  }

  toggle() {
    const eventType = this.typeTarget.value

    const isBiometry = this.isBiometryEvent(eventType)
    const isMortality = eventType === "mortality"
    const isFeeding = eventType === "feeding"
    const isLoading = eventType === "loading"

    this.toggleTarget("biometryRow", isBiometry)
    this.toggleTarget("mortalityRow", isMortality)
    this.toggleTarget("feedKgRow", isFeeding)
    this.toggleTarget("loadingRow", isLoading)

    if (!isBiometry) this.clearBiometryFields()
    if (!isMortality) this.clearMortalityFields()

    if (isLoading) this.recalculateLoading()
    if (isBiometry) this.recalculate()
    if (isMortality) this.recalculateMortality()
  }

  recalculate() {
    if (!this.hasTypeTarget || !this.isBiometryEvent(this.typeTarget.value)) return

    const quantity = this.parseNumber(this.hasQuantityTarget ? this.quantityTarget.value : "")
    const totalWeightKg = this.parseNumber(this.hasTotalWeightTarget ? this.totalWeightTarget.value : "")
    const volume = this.parseNumber(this.hasVolumeTarget ? this.volumeTarget.value : "")
    const previousBiomass = this.parseStoredNumber(
      this.hasPreviousBiomassTarget ? this.previousBiomassTarget.value : ""
    )
    const previousAvgWeight = this.parseStoredNumber(
      this.hasPreviousAvgWeightTarget ? this.previousAvgWeightTarget.value : ""
    )
    const previousOccurredOn = this.hasPreviousOccurredOnTarget ? this.previousOccurredOnTarget.value : ""
    const currentOccurredOn = this.hasOccurredOnTarget ? this.occurredOnTarget.value : ""
    const feedKg = this.parseNumber(this.hasFeedKgBiometryTarget ? this.feedKgBiometryTarget.value : "")

    let avgWeightG = 0
    let biomass = 0
    let weightGainKg = 0
    let gpd = 0
    let feedConversion = 0

    if (quantity > 0 && totalWeightKg > 0) {
      avgWeightG = (totalWeightKg / quantity) * 1000
    }

    if (volume > 0 && avgWeightG > 0) {
      biomass = volume * (avgWeightG / 1000)
    }

    if (biomass > 0) {
      weightGainKg = biomass - previousBiomass
    }

    const daysDiff = this.daysBetween(previousOccurredOn, currentOccurredOn)
    if (daysDiff > 0 && avgWeightG > 0 && previousAvgWeight > 0) {
      gpd = (avgWeightG - previousAvgWeight) / daysDiff
    }

    if (feedKg > 0 && weightGainKg > 0) {
      feedConversion = weightGainKg / feedKg
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

    if (this.hasFeedConversionTarget) {
      this.feedConversionTarget.value = this.formatDecimal(feedConversion, 3)
    }
  }

  recalculateLoading() {
    if (!this.hasTypeTarget || this.typeTarget.value !== "loading") return
    if (!this.hasLoadingTotalWeightTarget || !this.hasLoadingAvgWeightTarget || !this.hasLoadingQuantityTarget) return

    const totalWeightKg = this.parseNumber(this.loadingTotalWeightTarget.value)
    const avgWeightG = this.parseNumber(this.loadingAvgWeightTarget.value)

    let quantity = 0

    if (totalWeightKg > 0 && avgWeightG > 0) {
      quantity = (totalWeightKg * 1000) / avgWeightG
    }

    this.loadingQuantityTarget.value =
      quantity > 0 ? this.formatInteger(Math.ceil(quantity)) : ""
  }

  recalculateMortality() {
    if (!this.hasTypeTarget || this.typeTarget.value !== "mortality") return
    if (!this.hasMortalityQuantityTarget || !this.hasCurrentAvgWeightTarget) return

    const quantity = this.parseNumber(this.mortalityQuantityTarget.value)
    const avgWeight = this.parseStoredNumber(this.currentAvgWeightTarget.value)

    const totalWeightKg =
      quantity > 0 && avgWeight > 0
        ? (quantity * avgWeight) / 1000
        : 0

    if (this.hasMortalityAvgWeightTarget) {
      this.mortalityAvgWeightTarget.value = this.formatDecimal(avgWeight, 2)
    }

    if (this.hasMortalityWeightLossTarget) {
      this.mortalityWeightLossTarget.value = this.formatDecimal(totalWeightKg, 3)
    }
  }

  formatIntegerInput(event) {
    let value = event.target.value.replace(/\D/g, "")

    if (!value) {
      event.target.value = ""
      this.recalculate()
      this.recalculateLoading()
      return
    }

    event.target.value = this.formatWithDelimiter(value)
    this.recalculate()
    this.recalculateLoading()
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

  formatDecimalInput(event) {
    let value = event.target.value

    if (!value) {
      this.recalculate()
      this.recalculateLoading()
      return
    }

    value = value.replace(/[^0-9,\.]/g, "")

    const parts = value.split(/[,.]/)
    if (parts.length > 2) {
      value = parts[0] + "," + parts[1]
    }

    event.target.value = value
    this.recalculate()
    this.recalculateLoading()
  }

  maskCurrency(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "")

    if (!digits) {
      input.value = ""
      this.syncCurrencyHiddenTarget(input)
      return
    }

    const value = Number(digits) / 100
    input.value = this.formatCurrency(value)
    this.syncCurrencyHiddenTarget(input, Number(digits))
  }

  syncCurrencyHiddenTarget(input, cents = 0) {
    if (this.hasPricePerKgTarget && input === this.pricePerKgTarget && this.hasPricePerKgCentsTarget) {
      this.pricePerKgCentsTarget.value = cents
    }

    if (this.hasThousandValueTarget && input === this.thousandValueTarget && this.hasThousandValueCentsTarget) {
      this.thousandValueCentsTarget.value = cents
    }

    if (this.hasFreightCostTarget && input === this.freightCostTarget && this.hasFreightCostCentsTarget) {
      this.freightCostCentsTarget.value = cents
    }

    if (this.hasLoadingCostTarget && input === this.loadingCostTarget && this.hasLoadingCostCentsTarget) {
      this.loadingCostCentsTarget.value = cents
    }
  }

  toggleTarget(targetName, show) {
    const targetProperty = `has${this.capitalize(targetName)}Target`
    const elementProperty = `${targetName}Target`

    if (!this[targetProperty]) return

    const element = this[elementProperty]
    element.classList.toggle("hidden", !show)

    element.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !show
    })
  }

  clearBiometryFields() {
    if (this.hasAvgWeightTarget) this.avgWeightTarget.value = ""
    if (this.hasBiomassTarget) this.biomassTarget.value = ""
    if (this.hasWeightGainTarget) this.weightGainTarget.value = this.formatDecimal(0, 2)
    if (this.hasGpdTarget) this.gpdTarget.value = this.formatDecimal(0, 3)
    if (this.hasFeedConversionTarget) this.feedConversionTarget.value = this.formatDecimal(0, 3)
  }

  clearMortalityFields() {
    if (this.hasMortalityAvgWeightTarget) this.mortalityAvgWeightTarget.value = ""
    if (this.hasMortalityWeightLossTarget) this.mortalityWeightLossTarget.value = ""
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

    if (this.hasLoadingTotalWeightTarget) {
      const rawValue = this.loadingTotalWeightTarget.value
      const totalWeight = Number(rawValue)

      this.loadingTotalWeightTarget.value =
        !Number.isNaN(totalWeight) && totalWeight > 0
          ? this.formatDecimal(totalWeight, 3)
          : ""
    }

    if (this.hasLoadingAvgWeightTarget) {
      const rawValue = this.loadingAvgWeightTarget.value
      const avgWeight = Number(rawValue)

      this.loadingAvgWeightTarget.value =
        !Number.isNaN(avgWeight) && avgWeight > 0
          ? this.formatDecimal(avgWeight, 2)
          : ""
    }

    if (this.hasFeedKgBiometryTarget) {
      const rawValue = this.feedKgBiometryTarget.value
      const feedKg = Number(rawValue)

      this.feedKgBiometryTarget.value =
        !Number.isNaN(feedKg) && feedKg > 0
          ? this.formatDecimal(feedKg, 3)
          : ""
    }

    if (this.hasPricePerKgTarget) this.formatCurrencyInitial(this.pricePerKgTarget)
    if (this.hasThousandValueTarget) this.formatCurrencyInitial(this.thousandValueTarget)
    if (this.hasFreightCostTarget) this.formatCurrencyInitial(this.freightCostTarget)
    if (this.hasLoadingCostTarget) this.formatCurrencyInitial(this.loadingCostTarget)

    this.recalculate()
    this.recalculateMortality()
    this.recalculateLoading()
  }

  formatCurrencyInitial(input) {
    if (!input) return

    const digits = input.value.replace(/\D/g, "")
    if (!digits) return

    input.value = this.formatCurrency(Number(digits) / 100)
  }

  parseNumber(value) {
    if (value == null || value === "") return 0

    const normalized = String(value).trim().replace(/\./g, "").replace(",", ".")
    const parsed = parseFloat(normalized)

    return Number.isNaN(parsed) ? 0 : parsed
  }

  parseStoredNumber(value) {
    if (value == null || value === "") return 0

    const parsed = Number(String(value).trim())
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

  formatCurrency(value) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format(Number(value || 0))
  }

  formatWithDelimiter(value) {
    return value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }

  daysBetween(startDate, endDate) {
    if (!startDate || !endDate) return 0

    const startParts = String(startDate).split("-")
    const endParts = String(endDate).split("-")

    if (startParts.length !== 3 || endParts.length !== 3) return 0

    const start = new Date(
      Number(startParts[0]),
      Number(startParts[1]) - 1,
      Number(startParts[2])
    )

    const end = new Date(
      Number(endParts[0]),
      Number(endParts[1]) - 1,
      Number(endParts[2])
    )

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0

    const diffMs = end - start
    return Math.floor(diffMs / (1000 * 60 * 60 * 24))
  }

  isBiometryEvent(eventType) {
    return eventType === "biometrics" || eventType === "biometry"
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }
}
