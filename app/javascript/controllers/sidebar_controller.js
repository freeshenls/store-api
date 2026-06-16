import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.remove("open")
  }

  toggle() {
    this.element.classList.toggle("open")
  }
}
