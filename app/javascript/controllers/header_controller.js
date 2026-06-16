import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "menuIconOpen", "menuIconClose", "dropdown", "mobileCategoriesList", "mobileCategoriesIcon"]

  connect() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.remove("active")
    }
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.remove("open")
    }
    if (this.hasMenuIconOpenTarget) {
      this.menuIconOpenTarget.style.display = "block"
    }
    if (this.hasMenuIconCloseTarget) {
      this.menuIconCloseTarget.style.display = "none"
    }
  }

  toggleMobileCategories(e) {
    e.preventDefault()
    e.stopPropagation()
    if (this.hasMobileCategoriesListTarget) {
      const list = this.mobileCategoriesListTarget
      const isHidden = window.getComputedStyle(list).display === 'none'
      if (isHidden) {
        list.style.display = 'flex'
        if (this.hasMobileCategoriesIconTarget) {
          this.mobileCategoriesIconTarget.style.transform = 'rotate(180deg)'
        }
      } else {
        list.style.display = 'none'
        if (this.hasMobileCategoriesIconTarget) {
          this.mobileCategoriesIconTarget.style.transform = 'rotate(0deg)'
        }
      }
    }
  }

  toggleMobileMenu(e) {
    e.stopPropagation()
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle("open")
      const isOpen = this.mobileMenuTarget.classList.contains("open")
      if (this.hasMenuIconOpenTarget) {
        this.menuIconOpenTarget.style.display = isOpen ? "none" : "block"
      }
      if (this.hasMenuIconCloseTarget) {
        this.menuIconCloseTarget.style.display = isOpen ? "block" : "none"
      }
    }
  }

  toggleDropdown(e) {
    e.stopPropagation()
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle("active")
    }
  }

  clickOutside(e) {
    if (this.hasDropdownTarget && this.dropdownTarget.classList.contains("active")) {
      if (!this.dropdownTarget.contains(e.target)) {
        this.dropdownTarget.classList.remove("active")
      }
    }

    if (this.hasMobileMenuTarget && this.mobileMenuTarget.classList.contains("open")) {
      const toggleBtn = document.getElementById("mobile-menu-btn")
      if (!this.mobileMenuTarget.contains(e.target) && (!toggleBtn || !toggleBtn.contains(e.target))) {
        this.mobileMenuTarget.classList.remove("open")
        if (this.hasMenuIconOpenTarget) {
          this.menuIconOpenTarget.style.display = "block"
        }
        if (this.hasMenuIconCloseTarget) {
          this.menuIconCloseTarget.style.display = "none"
        }
      }
    }
  }
}
