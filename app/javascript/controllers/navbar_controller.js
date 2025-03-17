import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu"]

  connect() {
    this.mobileMenuVisible = false
  }

  toggleMenu() {
    this.mobileMenuVisible = !this.mobileMenuVisible
    
    if (this.mobileMenuVisible) {
      this.mobileMenuTarget.classList.remove("hidden")
    } else {
      this.mobileMenuTarget.classList.add("hidden")
    }
  }
}