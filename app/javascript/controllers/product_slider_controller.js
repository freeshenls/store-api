import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "item"]

  connect() {
    this.currentIndex = 0
    this.startX = 0
    this.endX = 0
    this.adjustPosition()
  }

  next() {
    if (window.innerWidth <= 768) return
    const maxIndex = this.getMaxIndex()
    if (this.currentIndex < maxIndex) {
      this.currentIndex++
      this.adjustPosition()
    }
  }

  prev() {
    if (window.innerWidth <= 768) return
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.adjustPosition()
    }
  }

  adjustPosition() {
    if (!this.hasTrackTarget || this.itemTargets.length === 0) return

    if (window.innerWidth <= 768) {
      this.trackTarget.style.transform = "none"
      return
    }

    const gap = 24
    const itemWidth = this.itemTargets[0].getBoundingClientRect().width + gap
    const offset = -this.currentIndex * itemWidth
    this.trackTarget.style.transform = `translateX(${offset}px)`
  }

  getMaxIndex() {
    if (!this.hasTrackTarget || this.itemTargets.length === 0) return 0
    const gap = 24
    const itemWidth = this.itemTargets[0].getBoundingClientRect().width + gap
    const containerWidth = this.element.querySelector(".product-slider-container").getBoundingClientRect().width
    const visibleCount = Math.round(containerWidth / itemWidth)
    return Math.max(0, this.itemTargets.length - visibleCount)
  }

  touchStart(e) {
    if (window.innerWidth <= 768) return
    this.startX = e.touches[0].clientX
    this.endX = e.touches[0].clientX
  }

  touchMove(e) {
    if (window.innerWidth <= 768) return
    this.endX = e.touches[0].clientX
  }

  touchEnd() {
    if (window.innerWidth <= 768) return
    const threshold = 40
    const diff = this.startX - this.endX
    if (Math.abs(diff) > threshold) {
      if (diff > 0) {
        this.next()
      } else {
        this.prev()
      }
    }
    this.startX = 0
    this.endX = 0
  }
}
