import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mainImage", "thumb", "dot",
    "lightboxModal", "lightboxImage", "lightboxCaption", "lightboxCounter"
  ]

  connect() {
    this.currentIndex = 0
    this.startX = 0
    this.endX = 0

    // Gather all image URLs from thumbnails
    this.imageUrls = this.thumbTargets.map(thumb => {
      const img = thumb.querySelector("img")
      return img ? img.src : ""
    })

    if (this.imageUrls.length === 0 && this.hasMainImageTarget) {
      this.imageUrls = [this.mainImageTarget.src]
    }

    this.title = this.element.getAttribute("data-title") || ""
  }

  selectImage(e) {
    const index = parseInt(e.currentTarget.getAttribute("data-index") || "0", 10)
    this.setImage(index)
  }

  setImage(index) {
    if (index < 0 || index >= this.imageUrls.length) return
    this.currentIndex = index

    if (this.hasMainImageTarget) {
      this.mainImageTarget.src = this.imageUrls[this.currentIndex]
    }

    this.thumbTargets.forEach((t, idx) => {
      t.classList.toggle("active", idx === this.currentIndex)
    })

    this.dotTargets.forEach((d, idx) => {
      d.classList.toggle("active", idx === this.currentIndex)
    })

    // Sync lightbox if open
    if (this.isLightboxOpen()) {
      this.updateLightboxContent()
    }
  }

  // Swipe gesture for main gallery
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
        let nextIdx = this.currentIndex + 1
        if (nextIdx >= this.imageUrls.length) nextIdx = 0
        this.setImage(nextIdx)
      } else {
        let prevIdx = this.currentIndex - 1
        if (prevIdx < 0) prevIdx = this.imageUrls.length - 1
        this.setImage(prevIdx)
      }
    }
    this.startX = 0
    this.endX = 0
  }

  // Lightbox swipe gesture
  lightboxTouchStart(e) {
    this.startX = e.touches[0].clientX
    this.endX = e.touches[0].clientX
  }

  lightboxTouchMove(e) {
    this.endX = e.touches[0].clientX
  }

  lightboxTouchEnd() {
    const threshold = 50
    const diff = this.startX - this.endX
    if (Math.abs(diff) > threshold) {
      if (diff > 0) {
        this.nextLightbox()
      } else {
        this.prevLightbox()
      }
    }
    this.startX = 0
    this.endX = 0
  }

  // Fullscreen Lightbox triggers
  openLightbox() {
    if (this.imageUrls.length === 0) return

    if (this.hasLightboxModalTarget) {
      this.lightboxModalTarget.classList.add("open")
      document.body.style.overflow = "hidden"
      this.updateLightboxContent()
    }
  }

  closeLightbox() {
    if (this.hasLightboxModalTarget) {
      this.lightboxModalTarget.classList.remove("open")
      document.body.style.overflow = ""
    }
  }

  closeLightboxOnOutsideClick(e) {
    if (e.target === this.lightboxModalTarget || e.target.classList.contains("lightbox-container")) {
      this.closeLightbox()
    }
  }

  nextLightbox() {
    let nextIdx = this.currentIndex + 1
    if (nextIdx >= this.imageUrls.length) nextIdx = 0
    this.setImage(nextIdx)
  }

  prevLightbox() {
    let prevIdx = this.currentIndex - 1
    if (prevIdx < 0) prevIdx = this.imageUrls.length - 1
    this.setImage(prevIdx)
  }

  handleKeydown(e) {
    if (!this.isLightboxOpen()) return

    if (e.key === "Escape") {
      this.closeLightbox()
    } else if (e.key === "ArrowRight") {
      this.nextLightbox()
    } else if (e.key === "ArrowLeft") {
      this.prevLightbox()
    }
  }

  isLightboxOpen() {
    return this.hasLightboxModalTarget && this.lightboxModalTarget.classList.contains("open")
  }

  updateLightboxContent() {
    if (!this.hasLightboxImageTarget) return

    const currentUrl = this.imageUrls[this.currentIndex]
    this.lightboxImageTarget.src = currentUrl

    if (this.hasLightboxCaptionTarget) {
      this.lightboxCaptionTarget.textContent = `${this.title} (Preview ${this.currentIndex + 1})`
    }

    if (this.hasLightboxCounterTarget) {
      this.lightboxCounterTarget.textContent = `${this.currentIndex + 1} / ${this.imageUrls.length}`
    }

    // Scroll active thumb into view if it exists on page
    const activeThumb = this.thumbTargets[this.currentIndex]
    if (activeThumb) {
      activeThumb.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" })
    }
  }
}
