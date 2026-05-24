import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "unitPrice", "lineTotal"]
  static values = {
    basePrice: Number,
    volumeRules: Array,
    currencySymbol: String
  }

  connect() {
    this.updatePrices()
  }

  quantityChanged() {
    this.updatePrices()
    // Emit an event to notify the cart page of the line item total change
    this.dispatch("updated", {
      detail: {
        lineItemId: this.element.id,
        lineTotal: this.calculateLineTotal()
      }
    })
  }

  calculateUnitPrice() {
    const qty = parseInt(this.quantityTarget.value, 10) || 1
    const base = this.basePriceValue
    const rules = this.volumeRulesValue

    const matchingRule = rules.find(rule => this.isQtyInRange(qty, rule.range))
    if (!matchingRule) return base

    return this.calculateRulePrice(base, matchingRule)
  }

  calculateLineTotal() {
    const qty = parseInt(this.quantityTarget.value, 10) || 1
    const unitPrice = this.calculateUnitPrice()
    return unitPrice * qty
  }

  updatePrices() {
    const qty = parseInt(this.quantityTarget.value, 10) || 1
    const unitPrice = this.calculateUnitPrice()
    const lineTotal = unitPrice * qty

    const currencySymbol = this.currencySymbolValue

    // Update unit price display
    if (this.hasUnitPriceTarget) {
      this.unitPriceTarget.textContent = currencySymbol + unitPrice.toFixed(2)
    }

    // Update line total display (both mobile and desktop targets)
    this.lineTotalTargets.forEach(target => {
      target.textContent = currencySymbol + lineTotal.toFixed(2)
    })
  }

  isQtyInRange(qty, rangeStr) {
    const cleanRange = rangeStr.replace(/[()]/g, '').trim()
    if (cleanRange.includes('..')) {
      const parts = cleanRange.split('..')
      const min = parseInt(parts[0], 10)
      const max = parts[1] ? parseInt(parts[1], 10) : Infinity
      return qty >= min && qty <= max
    } else if (cleanRange.includes('+')) {
      const min = parseInt(cleanRange.replace('+', ''), 10)
      return qty >= min
    }
    return false
  }

  calculateRulePrice(base, rule) {
    switch (rule.discount_type) {
      case 'price':
        return rule.amount
      case 'dollar':
        return base - rule.amount
      case 'percent':
        return base * (1.0 - rule.amount)
      default:
        return base
    }
  }
}
