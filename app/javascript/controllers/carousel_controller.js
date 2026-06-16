import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "dot"]

  connect() {
    this.currentVirtualIndex = 0
    this.isTransitioning = false
    this.slideTimer = null
    this.startX = 0
    this.endX = 0

    this.initCarouselClones()
    this.startSlideTimer()
  }

  disconnect() {
    this.stopSlideTimer()
  }


  initCarouselClones() {
    if (!this.hasTrackTarget) return
    const track = this.trackTarget
    if (track.dataset.cloned === "true") return

    const slides = Array.from(track.querySelectorAll(".carousel-slide"))
    if (slides.length <= 1) return

    const firstClone = slides[0].cloneNode(true)
    const lastClone = slides[slides.length - 1].cloneNode(true)

    firstClone.classList.add("carousel-clone")
    lastClone.classList.add("carousel-clone")

    track.appendChild(firstClone)
    track.insertBefore(lastClone, slides[0])

    track.dataset.cloned = "true"
    
    this.currentVirtualIndex = 0
    track.style.transform = `translateX(-100%)`
    
    this.dotTargets.forEach(dot => dot.classList.remove("active"))
    if (this.dotTargets[0]) this.dotTargets[0].classList.add("active")
    
    slides.forEach(slide => slide.classList.remove("active"))
    if (slides[0]) slides[0].classList.add("active")
  }

  showCarouselSlide(index) {
    if (!this.hasTrackTarget || this.isTransitioning) return
    const track = this.trackTarget

    const originalSlides = Array.from(track.querySelectorAll(".carousel-slide:not(.carousel-clone)"))
    const allSlides = Array.from(track.querySelectorAll(".carousel-slide"))
    if (originalSlides.length <= 1) return

    this.isTransitioning = true
    const N = originalSlides.length
    let targetDOMIndex = index + 1

    track.style.transform = `translateX(${-targetDOMIndex * 100}%)`

    let newVirtualIndex = index
    if (index >= N) {
      newVirtualIndex = 0
    } else if (index < 0) {
      newVirtualIndex = N - 1
    }

    this.dotTargets.forEach(dot => dot.classList.remove("active"))
    if (this.dotTargets[newVirtualIndex]) {
      this.dotTargets[newVirtualIndex].classList.add("active")
    }

    allSlides.forEach(slide => slide.classList.remove("active"))
    if (originalSlides[newVirtualIndex]) {
      originalSlides[newVirtualIndex].classList.add("active")
    }

    this.currentVirtualIndex = newVirtualIndex

    const handleTransitionEnd = () => {
      track.removeEventListener("transitionend", handleTransitionEnd)
      
      if (index >= N) {
        track.style.transition = "none"
        track.style.transform = `translateX(-100%)`
        track.offsetHeight // trigger reflow
        track.style.transition = ""
      } else if (index < 0) {
        track.style.transition = "none"
        track.style.transform = `translateX(${-N * 100}%)`
        track.offsetHeight // trigger reflow
        track.style.transition = ""
      }
      
      this.isTransitioning = false
    }

    track.addEventListener("transitionend", handleTransitionEnd)
  }

  prev() {
    if (this.isTransitioning) return
    this.showCarouselSlide(this.currentVirtualIndex - 1)
    this.startSlideTimer()
  }

  next() {
    if (this.isTransitioning) return
    this.showCarouselSlide(this.currentVirtualIndex + 1)
    this.startSlideTimer()
  }

  goToDot(e) {
    const idx = this.dotTargets.indexOf(e.currentTarget)
    if (idx !== -1) {
      this.showCarouselSlide(idx)
      this.startSlideTimer()
    }
  }

  startSlideTimer() {
    // Auto-play disabled
  }

  stopSlideTimer() {
    // Auto-play disabled
  }

  touchStart(e) {
    this.startX = e.touches[0].clientX
    this.endX = e.touches[0].clientX
  }

  touchMove(e) {
    this.endX = e.touches[0].clientX
  }

  touchEnd() {
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
