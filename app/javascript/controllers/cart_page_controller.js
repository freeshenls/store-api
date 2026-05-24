import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['updateButton']

  setQuantityToZero(e) {
    this.element.querySelector(`#${e.params.quantityId}`).value = '0'
  }

  disableUpdateButton() {
    this.updateButtonTarget.setAttribute('disabled', true)
  }

  handleItemUpdated(event) {
    this.updateOrderTotals()
  }

  updateOrderTotals() {
    // Sum all line item totals
    let itemTotal = 0
    const cartItems = this.element.querySelectorAll('[data-controller="cart-item"]')
    cartItems.forEach(item => {
      const qtyInput = item.querySelector('[data-cart-item-target="quantity"]')
      if (!qtyInput) return
      
      const qty = parseInt(qtyInput.value, 10) || 0
      
      // Calculate unit price using the rules of this item
      const basePrice = parseFloat(item.dataset.cartItemBasePriceValue || "0")
      const rules = JSON.parse(item.dataset.cartItemVolumeRulesValue || "[]")
      
      const isQtyInRange = (q, rangeStr) => {
        const cleanRange = rangeStr.replace(/[()]/g, '').trim()
        if (cleanRange.includes('..')) {
          const parts = cleanRange.split('..')
          const min = parseInt(parts[0], 10)
          const max = parts[1] ? parseInt(parts[1], 10) : Infinity
          return q >= min && q <= max
        } else if (cleanRange.includes('+')) {
          const min = parseInt(cleanRange.replace('+', ''), 10)
          return q >= min
        }
        return false
      }

      const calculateRulePrice = (base, rule) => {
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

      const calculateUnitPrice = (q, base, r) => {
        const matchingRule = r.find(rule => isQtyInRange(q, rule.range))
        if (!matchingRule) return base
        return calculateRulePrice(base, matchingRule)
      }

      const unitPrice = calculateUnitPrice(qty, basePrice, rules)
      itemTotal += unitPrice * qty
    })

    // Update order total and item subtotal in the sidebar / footer
    const currencySymbol = this.element.querySelector('[data-controller="cart-item"]')?.dataset.cartItemCurrencySymbolValue || "$"
    
    // Find item subtotal element in the DOM
    const subtotalLabel = this.element.querySelector('#cart_adjustments .cart-amount-row:first-child .font-sans-md')
    if (subtotalLabel) {
      subtotalLabel.textContent = currencySymbol + itemTotal.toFixed(2)
    }

    // Sum other static adjustments (tax, shipping, promotions, etc.)
    let otherAdjustments = 0
    const adjustmentRows = this.element.querySelectorAll('#cart_adjustments .cart-amount-row')
    adjustmentRows.forEach((row, index) => {
      // Skip the first row which is the Subtotal
      if (index === 0) return
      
      const amountSpan = row.querySelector('.font-sans-md')
      if (amountSpan) {
        const text = amountSpan.textContent.replace(/[^\d.-]/g, '')
        const val = parseFloat(text) || 0
        otherAdjustments += val
      }
    })

    const finalTotal = itemTotal + otherAdjustments
    
    // Update final total element
    const totalSpan = this.element.querySelector('.cart-footer__total .font-sans-md')
    if (totalSpan) {
      totalSpan.textContent = currencySymbol + finalTotal.toFixed(2)
    }
  }
}
