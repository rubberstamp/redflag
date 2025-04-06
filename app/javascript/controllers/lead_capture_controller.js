import { Controller } from "@hotwired/stimulus"

/**
 * Lead capture form controller
 * Handles the initial email capture form submission
 */
export default class extends Controller {
  static targets = ["form", "error"]

  connect() {
    console.log("Lead capture controller connected")
  }

  /**
   * The form has been submitted
   * @param {Event} event - Form submit event
   */
  async submit(event) {
    event.preventDefault()

    try {
      // Show loading state
      const submitButton = this.element.querySelector('button[type="submit"]')
      const originalText = submitButton.innerText
      submitButton.innerText = "Processing..."
      submitButton.disabled = true

      // Get form data
      const formData = new FormData(this.element)
      
      // Submit the form via fetch
      const response = await fetch(this.element.action, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: formData
      })

      const data = await response.json()

      // Reset button state
      submitButton.innerText = originalText
      submitButton.disabled = false

      if (response.ok) {
        if (data.success) {
          // Redirect to the choose import page
          window.location.href = data.redirect_url || "/leads/choose_import"
        } else {
          this.showErrors(data.errors || ["An unknown error occurred"])
        }
      } else {
        // Handle error response
        this.showErrors(data.errors || ["An error occurred while processing your request"])
      }
    } catch (error) {
      console.error("Error submitting lead form:", error)
      this.showErrors(["An unexpected error occurred. Please try again."])
    }
  }

  /**
   * Display form errors
   * @param {Array} errors - Array of error messages
   */
  showErrors(errors) {
    const errorsContainer = document.getElementById('initial-lead-errors')
    if (!errorsContainer) return

    errorsContainer.classList.remove('hidden')
    errorsContainer.innerHTML = ''
    
    if (errors.length) {
      const ul = document.createElement('ul')
      ul.classList.add('list-disc', 'pl-5')
      
      errors.forEach(error => {
        const li = document.createElement('li')
        li.textContent = error
        ul.appendChild(li)
      })
      
      errorsContainer.appendChild(ul)
    } else {
      errorsContainer.textContent = 'An error occurred. Please try again.'
    }
  }
}