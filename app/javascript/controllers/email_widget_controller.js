import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["widget", "collapsed"]

  connect() {
    this.minimize()
  }

  minimize() {
    if (this.hasWidgetTarget) {
      this.widgetTarget.classList.add("minimized")
    }
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.style.display = "flex"
    }
  }

  expand() {
    if (this.hasWidgetTarget) {
      this.widgetTarget.classList.remove("minimized")
    }
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.style.display = "none"
    }
  }
}
