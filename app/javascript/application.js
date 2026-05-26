// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Global Image Swapping method for product detail thumbnails
window.changeImage = function(element) {
  const mainImage = document.getElementById("mainImage");
  if (!mainImage) return;
  
  const imgInside = element.querySelector("img");
  if (!imgInside) return;
  
  // Swap source and alt text
  mainImage.src = imgInside.src;
  if (imgInside.alt) mainImage.alt = imgInside.alt;
  
  // Reset active classes on all siblings
  const parent = element.parentElement;
  if (parent) {
    parent.querySelectorAll(".thumb").forEach(t => t.classList.remove("active"));
  }
  element.classList.add("active");
};

// ----------------------------------------------------
// Unified Global Interactive UI Controller for Zevi Store
// Handles Carousels, Dropdowns, Accordions with event delegation
// and Turbo lifecycle management to prevent memory leaks and duplication.
// ----------------------------------------------------

// Global Carousel functions
function showCarouselSlide(index) {
  const slides = document.querySelectorAll(".carousel-slide");
  const dots = document.querySelectorAll(".carousel-dot");
  if (slides.length === 0) return;

  let currentSlide = index;
  if (index >= slides.length) {
    currentSlide = 0;
  } else if (index < 0) {
    currentSlide = slides.length - 1;
  }

  // Hide all slides & deactivate all dots
  slides.forEach(slide => slide.classList.remove("active"));
  dots.forEach(dot => dot.classList.remove("active"));

  // Show target slide & dot
  if (slides[currentSlide]) {
    slides[currentSlide].classList.add("active");
  }
  if (dots[currentSlide]) {
    dots[currentSlide].classList.add("active");
  }
}

function navigateCarousel(offset) {
  const slides = document.querySelectorAll(".carousel-slide");
  if (slides.length === 0) return;
  
  // Find currently active slide
  const currentIndex = Array.from(slides).findIndex(slide => slide.classList.contains("active"));
  const targetIndex = (currentIndex === -1) ? 0 : (currentIndex + offset);
  showCarouselSlide(targetIndex);
}

function startSlideTimer() {
  stopSlideTimer();
  const slides = document.querySelectorAll(".carousel-slide");
  if (slides.length > 1) {
    window.slideTimer = setInterval(function() {
      navigateCarousel(1);
    }, 5000);
  }
}

function stopSlideTimer() {
  if (window.slideTimer) {
    clearInterval(window.slideTimer);
    window.slideTimer = null;
  }
}

// Register global event listeners ONCE (persists across Turbo page changes)
if (!window.zeviListenersRegistered) {
  document.addEventListener("click", function(e) {
    // 1. Mobile Menu Button click
    const mobileMenuBtn = e.target.closest("#mobile-menu-btn");
    if (mobileMenuBtn) {
      e.stopPropagation();
      const mobileDropdown = document.getElementById("mobile-dropdown-menu");
      if (mobileDropdown) {
        mobileDropdown.classList.toggle("open");
        const isOpen = mobileDropdown.classList.contains("open");
        const icon = mobileMenuBtn.querySelector(".material-symbols-outlined");
        if (icon) icon.textContent = isOpen ? "close" : "menu";
      }
      return;
    }

    // 2. Mobile Menu outside click
    const mobileDropdown = document.getElementById("mobile-dropdown-menu");
    if (mobileDropdown && mobileDropdown.classList.contains("open")) {
      if (!mobileDropdown.contains(e.target)) {
        mobileDropdown.classList.remove("open");
        const btn = document.getElementById("mobile-menu-btn");
        const icon = btn?.querySelector(".material-symbols-outlined");
        if (icon) icon.textContent = "menu";
      }
    }

    // 3. Desktop navbar Categories Dropdown click
    const dropdownTrigger = e.target.closest(".dropdown-trigger");
    if (dropdownTrigger) {
      e.stopPropagation();
      dropdownTrigger.classList.toggle("active");
      return;
    }

    // 4. Desktop navbar Categories Dropdown outside click
    const activeDropdown = document.querySelector(".dropdown-trigger.active");
    if (activeDropdown && !activeDropdown.contains(e.target)) {
      activeDropdown.classList.remove("active");
    }

    // 5. Mobile Category Filter Accordion toggle click
    const filterToggleBtn = e.target.closest("#filter-toggle-btn");
    if (filterToggleBtn) {
      const categoriesSidebar = document.querySelector(".categories-sidebar");
      if (categoriesSidebar) {
        categoriesSidebar.classList.toggle("open");
      }
      return;
    }

    // 6. Carousel Prev Button
    const prevBtn = e.target.closest("#prev-btn");
    if (prevBtn) {
      navigateCarousel(-1);
      // Restart timer to reset interval on interaction
      startSlideTimer();
      return;
    }

    // 7. Carousel Next Button
    const nextBtn = e.target.closest("#next-btn");
    if (nextBtn) {
      navigateCarousel(1);
      startSlideTimer();
      return;
    }

    // 8. Carousel Dot Button
    const carouselDot = e.target.closest(".carousel-dot");
    if (carouselDot) {
      const dots = Array.from(document.querySelectorAll(".carousel-dot"));
      const idx = dots.indexOf(carouselDot);
      if (idx !== -1) {
        showCarouselSlide(idx);
      }
      return;
    }

    // 9. Floating Email Widget Hide Click
    const widgetToggleBtn = e.target.closest("#widget-toggle-btn");
    if (widgetToggleBtn) {
      const widget = document.getElementById("floating-email-widget");
      const collapsed = document.getElementById("floating-email-collapsed");
      if (widget && collapsed) {
        widget.classList.add("minimized");
        collapsed.style.display = "flex";
      }
      return;
    }

    // 10. Floating Email Widget Show/Expand Click
    const collapsedBtn = e.target.closest("#floating-email-collapsed");
    if (collapsedBtn) {
      const widget = document.getElementById("floating-email-widget");
      if (widget) {
        collapsedBtn.style.display = "none";
        widget.classList.remove("minimized");
      }
      return;
    }

    // 11. Thumbnail image swap inside product detail view
    const thumbEl = e.target.closest(".thumb");
    if (thumbEl) {
      window.changeImage(thumbEl);
      return;
    }

    // 12. Toggle Artwork & Special Requests Container
    const toggleArtworkBtn = e.target.closest("#toggle-artwork-btn");
    if (toggleArtworkBtn) {
      e.preventDefault();
      const container = document.getElementById("artwork-upload-container");
      if (container) {
        const isHidden = container.style.display === "none" || !container.style.display;
        container.style.display = isHidden ? "flex" : "none";
        toggleArtworkBtn.innerHTML = isHidden
          ? '<span class="material-symbols-outlined" style="font-size: 18px; color: var(--highlight-red);">remove_circle</span><span>Remove Artwork & Special Requests</span>'
          : '<span class="material-symbols-outlined" style="font-size: 18px; color: var(--primary);">add_photo_alternate</span><span>Add Artwork & Special Requests (Optional)</span>';
      }
      return;
    }
  });

  window.zeviListenersRegistered = true;
}

// Turbo load lifecycle initializer
document.addEventListener("turbo:load", function() {
  // Always stop existing slide timer first to prevent duplication
  stopSlideTimer();

  // If carousel elements are present, start auto-play
  const slides = document.querySelectorAll(".carousel-slide");
  if (slides.length > 1) {
    // Initial display reset (make sure first slide is active)
    showCarouselSlide(0);
    startSlideTimer();
  }

  // Ensure dropdown states are reset on page load
  const dropdownTrigger = document.querySelector(".dropdown-trigger");
  if (dropdownTrigger) {
    dropdownTrigger.classList.remove("active");
  }

  const mobileDropdown = document.getElementById("mobile-dropdown-menu");
  if (mobileDropdown) {
    mobileDropdown.classList.remove("open");
    const btn = document.getElementById("mobile-menu-btn");
    const icon = btn?.querySelector(".material-symbols-outlined");
    if (icon) icon.textContent = "menu";
  }

  const categoriesSidebar = document.querySelector(".categories-sidebar");
  if (categoriesSidebar) {
    categoriesSidebar.classList.remove("open");
  }

  // Reset floating email widget to collapsed/minimized state on page load
  const collapsedBtn = document.getElementById("floating-email-collapsed");
  if (collapsedBtn) {
    collapsedBtn.style.display = "flex";
  }
  const widget = document.getElementById("floating-email-widget");
  if (widget) {
    widget.classList.add("minimized");
  }
});

// Clear slide timer before caching the page to prevent any background tasks
document.addEventListener("turbo:before-cache", function() {
  stopSlideTimer();
});
