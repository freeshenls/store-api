import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "quantityInput", "step", "navItem", "form",
    "firstName", "lastName", "companyName", "email",
    "phoneCountry", "phonePrefix", "phoneInput", "submitBtn"
  ]

  connect() {
    this.currentStep = 1
    this.highlightPricingTier()
  }

  nextStep(e) {
    if (e) e.preventDefault()
    
    if (this.currentStep === 1) {
      if (!this.validateStep1()) return
    }

    this.currentStep = 2
    this.updateStepVisibility()
  }

  prevStep(e) {
    if (e) e.preventDefault()
    
    this.currentStep = 1
    this.updateStepVisibility()
  }

  goToStep(e) {
    e.preventDefault()
    const targetStep = parseInt(e.currentTarget.getAttribute("data-step"), 10)
    if (targetStep === this.currentStep) return

    if (targetStep === 2) {
      if (!this.validateStep1()) return
    }

    this.currentStep = targetStep
    this.updateStepVisibility()
  }

  highlightPricingTier() {
    if (!this.hasQuantityInputTarget) return
    const qty = parseInt(this.quantityInputTarget.value, 10)
    
    const rows = Array.from(document.querySelectorAll("[data-qty]"))
    if (rows.length === 0) return

    rows.forEach(row => {
      row.classList.remove("bg-[#074277]/10", "font-bold")
    })

    if (isNaN(qty) || qty <= 0) return

    const sortedRows = rows.map(row => ({
      element: row,
      threshold: parseInt(row.getAttribute("data-qty"), 10)
    })).sort((a, b) => b.threshold - a.threshold)

    const matchingRow = sortedRows.find(item => qty >= item.threshold)
    if (matchingRow) {
      matchingRow.element.classList.add("bg-[#074277]/10", "font-bold")
    }
  }

  validateStep1() {
    if (this.hasFirstNameTarget && !this.firstNameTarget.value.trim()) {
      this.firstNameTarget.reportValidity()
      return false
    }
    if (this.hasLastNameTarget && !this.lastNameTarget.value.trim()) {
      this.lastNameTarget.reportValidity()
      return false
    }
    if (this.hasCompanyNameTarget && !this.companyNameTarget.value.trim()) {
      this.companyNameTarget.reportValidity()
      return false
    }
    if (this.hasEmailTarget && (!this.emailTarget.value.trim() || !this.emailTarget.checkValidity())) {
      this.emailTarget.reportValidity()
      return false
    }
    return true
  }

  updateStepVisibility() {
    // Update step containers
    this.stepTargets.forEach(stepEl => {
      const stepNum = parseInt(stepEl.getAttribute("data-step"), 10)
      stepEl.classList.toggle("active", stepNum === this.currentStep)
    })

    // Update step nav headers
    this.navItemTargets.forEach(item => {
      const stepNum = parseInt(item.getAttribute("data-step"), 10)
      if (stepNum === this.currentStep) {
        item.classList.add("active")
        item.classList.remove("completed")
      } else if (stepNum < this.currentStep) {
        item.classList.remove("active")
        item.classList.add("completed")
      } else {
        item.classList.remove("active", "completed")
      }
    })
  }

  updatePhonePrefix() {
    if (!this.hasPhoneCountryTarget || !this.hasPhonePrefixTarget) return
    const country = this.phoneCountryTarget.value
    let prefix = "+1"
    if (country === "Canada") {
      prefix = "+1"
    } else if (country === "United Kingdom") {
      prefix = "+44"
    } else if (country === "Australia") {
      prefix = "+61"
    }
    this.phonePrefixTarget.value = prefix
  }

  applyQuantity(e) {
    const qty = e.currentTarget.getAttribute("data-qty")
    if (this.hasQuantityInputTarget) {
      this.quantityInputTarget.value = qty
      this.highlightPricingTier()
    }
  }

  submitForm(e) {
    e.preventDefault()

    if (!this.validateStep1()) {
      this.prevStep()
      setTimeout(() => {
        if (this.hasFirstNameTarget && !this.firstNameTarget.value.trim()) this.firstNameTarget.focus()
        else if (this.hasLastNameTarget && !this.lastNameTarget.value.trim()) this.lastNameTarget.focus()
        else if (this.hasCompanyNameTarget && !this.companyNameTarget.value.trim()) this.companyNameTarget.focus()
        else if (this.hasEmailTarget) this.emailTarget.focus()
      }, 100)
      return
    }

    if (!this.hasFormTarget || !this.hasSubmitBtnTarget) return

    const submitBtn = this.submitBtnTarget
    const originalBtnContent = submitBtn.innerHTML
    
    submitBtn.disabled = true
    submitBtn.innerHTML = '<span>Sending...</span><svg class="animate-spin size-4 inline-block align-middle" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99" /></svg>'
    
    const formData = new FormData(this.formTarget)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    fetch('/inquiries', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json().then(data => ({ status: response.status, data })))
    .then(({ status, data }) => {
      if (status === 200 && data.success) {
        alert(data.message)
        this.resetForm()
      } else {
        const errors = data.errors ? data.errors.join('\n') : 'An unexpected error occurred.'
        alert('Submission Failed:\n' + errors)
        submitBtn.disabled = false
        submitBtn.innerHTML = originalBtnContent
      }
    })
    .catch(err => {
      alert('An unexpected error occurred. Please try again.')
      submitBtn.disabled = false
      submitBtn.innerHTML = originalBtnContent
    })
  }

  resetForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    this.currentStep = 1
    this.updateStepVisibility()
    if (this.hasPhonePrefixTarget) {
      this.phonePrefixTarget.value = "+1"
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = false
    }
    this.highlightPricingTier()
  }
}
