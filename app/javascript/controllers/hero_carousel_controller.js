import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = {
    index: { type: Number, default: 0 },
    autoplayInterval: { type: Number, default: 5000 }
  }

  connect() {
    this.showCurrentSlide()
    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()
  }

  next() {
    this.indexValue = (this.indexValue + 1) % this.slideTargets.length
    this.showCurrentSlide()
  }

  previous() {
    this.indexValue = (this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length
    this.showCurrentSlide()
  }

  goTo(event) {
    const slideIndex = parseInt(event.currentTarget.dataset.index)
    if (!isNaN(slideIndex)) {
      this.indexValue = slideIndex
      this.showCurrentSlide()
      this.resetAutoplay()
    }
  }

  showCurrentSlide() {
    this.slideTargets.forEach((slide, idx) => {
      if (idx === this.indexValue) {
        // Active slide
        slide.classList.remove("opacity-0", "pointer-events-none")
        slide.classList.add("opacity-100", "pointer-events-auto", "z-10")
      } else {
        // Inactive slide
        slide.classList.remove("opacity-100", "pointer-events-auto", "z-10")
        slide.classList.add("opacity-0", "pointer-events-none")
      }
    })

    this.dotTargets.forEach((dot, idx) => {
      if (idx === this.indexValue) {
        // Active dot
        dot.classList.remove("bg-white/40", "w-2")
        dot.classList.add("bg-[#C33C39]", "w-6")
      } else {
        // Inactive dot
        dot.classList.remove("bg-[#C33C39]", "w-6")
        dot.classList.add("bg-white/40", "w-2")
      }
    })
  }

  startAutoplay() {
    this.autoplayTimer = setInterval(() => {
      this.next()
    }, this.autoplayIntervalValue)
  }

  stopAutoplay() {
    if (this.autoplayTimer) {
      clearInterval(this.autoplayTimer)
    }
  }

  resetAutoplay() {
    this.stopAutoplay()
    this.startAutoplay()
  }

  pause() {
    this.stopAutoplay()
  }

  resume() {
    this.startAutoplay()
  }
}
