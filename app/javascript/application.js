// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Global Image Swapping method for product detail thumbnails
window.changeImage = function(element) {
  const mainImage = document.getElementById("mainImage");
  if (!mainImage) return;
  
  // Try to read large source from data-large-src attribute to avoid blurry/shrunk thumbnails
  const largeSrc = element.getAttribute("data-large-src");
  const imgInside = element.querySelector("img");
  
  if (largeSrc) {
    mainImage.src = largeSrc;
  } else if (imgInside) {
    mainImage.src = imgInside.src;
  }
  
  if (imgInside && imgInside.alt) mainImage.alt = imgInside.alt;
  
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

  // Deactivate all slides & dots
  slides.forEach(slide => slide.classList.remove("active"));
  dots.forEach(dot => dot.classList.remove("active"));

  // Show target slide & dot
  if (slides[currentSlide]) {
    slides[currentSlide].classList.add("active");
  }
  if (dots[currentSlide]) {
    dots[currentSlide].classList.add("active");
  }

  // Translate the slider track horizontally
  const track = document.querySelector(".carousel-slides");
  if (track) {
    track.style.transform = `translateX(${-currentSlide * 100}%)`;
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



    // 13. Toggle Inline Request Info Stepper Form
    const pricingRequestBtn = e.target.closest("#pricing-request-btn");
    if (pricingRequestBtn) {
      e.preventDefault();
      const stepperContainer = document.getElementById("inline-stepper-container");
      if (stepperContainer) {
        const isHidden = stepperContainer.style.display === "none" || !stepperContainer.style.display;
        if (isHidden) {
          stepperContainer.style.display = "block";
          // Scroll inline stepper into view smoothly
          stepperContainer.scrollIntoView({ behavior: "smooth", block: "nearest" });
        } else {
          stepperContainer.style.display = "none";
        }
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

    // Register mobile touch swipe gestures on the carousel wrapper
    const wrapper = document.querySelector(".carousel-wrapper");
    if (wrapper && !wrapper.dataset.swipeRegistered) {
      let startX = 0;
      let endX = 0;

      wrapper.addEventListener("touchstart", function(e) {
        startX = e.touches[0].clientX;
        endX = e.touches[0].clientX; // Defensive initialization
      }, { passive: true });

      wrapper.addEventListener("touchmove", function(e) {
        endX = e.touches[0].clientX;
      }, { passive: true });

      wrapper.addEventListener("touchend", function() {
        const threshold = 40; // swipe threshold in pixels
        const diff = startX - endX;
        if (Math.abs(diff) > threshold) {
          if (diff > 0) {
            // Swiped left -> show next slide
            navigateCarousel(1);
            startSlideTimer();
          } else {
            // Swiped right -> show prev slide
            navigateCarousel(-1);
            startSlideTimer();
          }
        }
        startX = 0;
        endX = 0;
      });

      wrapper.dataset.swipeRegistered = "true";
    }
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

  // Initialize Air Datepicker on any elements with class .flatpickr
  const dateInputs = document.querySelectorAll(".flatpickr");
  const localeEn = {
    days: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
    daysShort: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    daysMin: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
    months: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
    monthsShort: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    today: 'Today',
    clear: 'Clear',
    dateFormat: 'MM/dd/yyyy',
    timeFormat: 'hh:mm aa',
    firstDay: 0
  };

  dateInputs.forEach(el => {
    if (el && window.AirDatepicker) {
      // Destroy any existing instance to ensure fresh initialization with the correct upward position
      if (el.airDatepickerInstance) {
        el.airDatepickerInstance.destroy();
      }
      
      el.airDatepickerInstance = new window.AirDatepicker(el, {
        autoClose: true,
        minDate: new Date(),
        locale: localeEn,
        position: 'top left'
      });
      el.dataset.airDatepickerInitialized = "true";
    }
  });
});

// Clear slide timer before caching the page to prevent any background tasks
document.addEventListener("turbo:before-cache", function() {
  stopSlideTimer();
});

// Toggle Zevi Specifications Accordion smoothly
window.toggleZeviAccordion = function(button) {
  const container = button.closest(".attributesContainer");
  if (!container) return;
  
  const content = container.querySelector(".contentContainer");
  if (!content) return;
  
  const isOpen = container.classList.contains("open");
  if (isOpen) {
    content.style.maxHeight = null;
    container.classList.remove("open");
  } else {
    container.classList.add("open");
    // Calculate scrollHeight after classList.add("open") to ensure padding is fully included!
    // Plus a 20px safety buffer to guarantee zero cutoffs across all browsers
    content.style.maxHeight = (content.scrollHeight + 20) + "px";
  }
};

// Stepper Navigation Helpers
window.nextStepperStep = function(currentStep) {
  if (currentStep === 1) {
    // Validate required fields in Step 1
    const firstName = document.querySelector('input[name="first_name"]');
    const lastName = document.querySelector('input[name="last_name"]');
    const companyName = document.querySelector('input[name="company_name"]');
    const email = document.querySelector('input[name="email"]');
    
    if (firstName && !firstName.value.trim()) {
      firstName.reportValidity();
      return;
    }
    if (lastName && !lastName.value.trim()) {
      lastName.reportValidity();
      return;
    }
    if (companyName && !companyName.value.trim()) {
      companyName.reportValidity();
      return;
    }
    if (email && (!email.value.trim() || !email.checkValidity())) {
      email.reportValidity();
      return;
    }
  }

  // Go to next step
  const nextStep = currentStep + 1;
  const currentStepEl = document.querySelector(`.stepper-step[data-step="${currentStep}"]`);
  const nextStepEl = document.querySelector(`.stepper-step[data-step="${nextStep}"]`);
  
  if (currentStepEl && nextStepEl) {
    currentStepEl.classList.remove("active");
    nextStepEl.classList.add("active");
    
    // Update step dots
    const dots = document.querySelectorAll('.step-dot');
    dots.forEach(dot => {
      const stepNum = parseInt(dot.getAttribute('data-step'));
      if (stepNum === nextStep) {
        dot.classList.add('active');
        dot.classList.remove('completed');
      } else if (stepNum < nextStep) {
        dot.classList.remove('active');
        dot.classList.add('completed');
      } else {
        dot.classList.remove('active', 'completed');
      }
    });

    // Update connector lines
    const lines = document.querySelectorAll('.step-line');
    lines.forEach((line, index) => {
      if (index < nextStep - 1) {
        line.classList.add('active');
      } else {
        line.classList.remove('active');
      }
    });
  }
};

window.prevStepperStep = function(currentStep) {
  const prevStep = currentStep - 1;
  const currentStepEl = document.querySelector(`.stepper-step[data-step="${currentStep}"]`);
  const prevStepEl = document.querySelector(`.stepper-step[data-step="${prevStep}"]`);
  
  if (currentStepEl && prevStepEl) {
    currentStepEl.classList.remove("active");
    prevStepEl.classList.add("active");
    
    // Update step dots
    const dots = document.querySelectorAll('.step-dot');
    dots.forEach(dot => {
      const stepNum = parseInt(dot.getAttribute('data-step'));
      if (stepNum === prevStep) {
        dot.classList.add('active');
        dot.classList.remove('completed');
      } else if (stepNum < prevStep) {
        dot.classList.remove('active');
        dot.classList.add('completed');
      } else {
        dot.classList.remove('active', 'completed');
      }
    });

    // Update connector lines
    const lines = document.querySelectorAll('.step-line');
    lines.forEach((line, index) => {
      if (index < prevStep - 1) {
        line.classList.add('active');
      } else {
        line.classList.remove('active');
      }
    });
  }
};

// Reset Stepper to Step 1
window.resetZeviStepper = function() {
  const form = document.getElementById("inline-quote-form");
  if (form) form.reset();

  const stepperContainer = document.getElementById("inline-stepper-container");
  if (stepperContainer) stepperContainer.style.display = "none";

  // Reset steps
  const steps = document.querySelectorAll('.stepper-step');
  steps.forEach((step, index) => {
    if (index === 0) {
      step.classList.add('active');
    } else {
      step.classList.remove('active');
    }
  });

  // Reset dots
  const dots = document.querySelectorAll('.step-dot');
  dots.forEach((dot, index) => {
    if (index === 0) {
      dot.classList.add('active');
      dot.classList.remove('completed');
    } else {
      dot.classList.remove('active', 'completed');
    }
  });

  // Reset lines
  const lines = document.querySelectorAll('.step-line');
  lines.forEach(line => line.classList.remove('active'));
};
