import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  switchTab(event) {
    event.preventDefault()
    const tabId = event.currentTarget.dataset.tabId
    
    // Deactivate all tab buttons
    this.element.querySelectorAll("[data-action='click->tabs#switchTab']").forEach(btn => {
      btn.classList.remove("border-black", "text-black")
      btn.classList.add("border-transparent", "text-shade-40", "hover:text-black")
    })
    
    // Activate clicked tab button
    event.currentTarget.classList.add("border-black", "text-black")
    event.currentTarget.classList.remove("border-transparent", "text-shade-40", "hover:text-black")
    
    // Hide all tab panels
    this.element.querySelectorAll(".tab-panel").forEach(panel => {
      panel.classList.add("hidden")
    })
    
    // Show active tab panel
    const activePanel = this.element.querySelector(`#panel-${tabId}`)
    if (activePanel) {
      activePanel.classList.remove("hidden")
    }
  }
}
