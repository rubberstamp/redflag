import { Controller } from "@hotwired/stimulus"

/**
 * Feature flags controller for handling PostHog feature flags
 */
export default class extends Controller {
  static values = {
    defaultLandingPage: String
  }
  
  connect() {
    // Check if there's a stored variant in the session
    const storedVariant = sessionStorage.getItem('landing_page_variant');
    if (storedVariant) {
      this.redirectToVariant(storedVariant);
      return;
    }
    
    // If no stored variant, check if PostHog is loaded
    if (typeof window.posthog !== 'undefined') {
      // Wait for feature flags to load
      window.posthog.onFeatureFlags(() => {
        this.handleLandingPageVariant();
      });
    } else {
      console.warn('PostHog not available for feature flags');
      // Default to the first variant if PostHog isn't available
      this.redirectToVariant(this.defaultLandingPageValue || 'cfo');
    }
  }
  
  handleLandingPageVariant() {
    // Get the landing page variant from feature flag
    const variant = window.posthog.getFeatureFlag('landing-page-variant');
    
    if (variant) {
      // Store the variant in session storage for consistency
      sessionStorage.setItem('landing_page_variant', variant);
      
      // Redirect to the appropriate landing page
      this.redirectToVariant(variant);
    } else {
      // If no variant is assigned, use the default
      this.redirectToVariant(this.defaultLandingPageValue || 'cfo');
    }
  }
  
  redirectToVariant(variant) {
    if (variant === 'cfo' || variant === 'small_business' || variant === 'quickbooks') {
      // Preserve any UTM parameters in the URL
      const currentUrl = new URL(window.location.href);
      const utmParams = new URLSearchParams();
      
      // Extract UTM parameters
      for (const [key, value] of currentUrl.searchParams.entries()) {
        if (key.startsWith('utm_')) {
          utmParams.append(key, value);
        }
      }
      
      // Build the new URL with the variant and UTM parameters
      let targetUrl = `/landing_pages/${variant}`;
      if (utmParams.toString()) {
        targetUrl += `?${utmParams.toString()}`;
      }
      
      // Only redirect if we're on the homepage
      if (window.location.pathname === '/' || window.location.pathname === '/landing_page_test') {
        window.location.href = targetUrl;
      }
    }
  }
}