import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "pane", "accordion"]

  switch(e) {
    const tabName = e.currentTarget.getAttribute("data-tab")

    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab.getAttribute("data-tab") === tabName)
    })

    this.paneTargets.forEach(pane => {
      pane.classList.toggle("active", pane.id === `tab-${tabName}`)
    })
  }

  toggleAccordion(e) {
    const item = e.currentTarget.closest(".accordion-item")
    if (item) {
      item.classList.toggle("open")
      const content = item.querySelector(".accordion-content")
      if (content) {
        content.style.display = item.classList.contains("open") ? "block" : "none"
      }
    }
  }
}
