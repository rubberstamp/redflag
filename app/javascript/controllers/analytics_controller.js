import { Controller } from "@hotwired/stimulus"

/**
 * Analytics controller for tracking events with PostHog
 */
export default class extends Controller {
  static values = {
    event: String,
    properties: Object
  }

  connect() {
    // Check if we have any event to track on connect
    if (this.hasEventValue) {
      this.trackEvent(this.eventValue, this.hasPropertiesValue ? this.propertiesValue : {})
    }
  }

  /**
   * Track a form submission event (to be used with form submit event)
   * @param {Event} event - The form submit event
   */
  trackFormSubmit(event) {
    // Get form data
    const form = event.target
    const formData = new FormData(form)
    const data = {}
    
    // Convert FormData to a plain object, excluding sensitive fields
    for (let [key, value] of formData.entries()) {
      // Skip sensitive information
      if (!key.includes('password') && !key.includes('token')) {
        // For nested attributes, handle them properly
        if (key.includes('[') && key.includes(']')) {
          const matches = key.match(/([^\[]+)\[([^\]]+)\]/)
          if (matches && matches.length === 3) {
            const formName = matches[1]
            const fieldName = matches[2]
            
            if (!data[formName]) {
              data[formName] = {}
            }
            
            data[formName][fieldName] = value
          }
        } else {
          data[key] = value
        }
      }
    }
    
    // Get event name from data attribute or use default
    const eventName = this.hasEventValue ? this.eventValue : "form_submitted"
    
    // Merge form data with any additional properties
    const properties = {
      form_id: form.id || null,
      form_name: form.name || null,
      form_action: form.action || null,
      ...data,
      ...(this.hasPropertiesValue ? this.propertiesValue : {})
    }
    
    // Track the event
    this.trackEvent(eventName, properties)
  }

  /**
   * Track a generic event with the given name and properties
   * @param {string} eventName - Name of the event to track
   * @param {Object} properties - Properties to include with the event
   */
  trackEvent(eventName, properties = {}) {
    if (typeof window.posthog !== 'undefined') {
      console.log(`Tracking event: ${eventName}`, properties)
      window.posthog.capture(eventName, properties)
    } else {
      console.warn('PostHog not available for tracking event:', eventName)
    }
  }
  
  /**
   * Track a click event
   * @param {Event} event - The click event
   */
  trackClick(event) {
    const element = event.currentTarget
    const eventName = this.hasEventValue ? this.eventValue : "element_clicked"
    
    const properties = {
      element_id: element.id || null,
      element_text: element.innerText || null,
      element_href: element.href || null,
      ...this.hasPropertiesValue ? this.propertiesValue : {}
    }
    
    this.trackEvent(eventName, properties)
  }
}