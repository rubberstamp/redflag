class PagesController < ApplicationController
  def home
  end
  
  def pricing
    # Static pricing page
  end
  
  def enterprise
    # Static enterprise page
  end
  
  # Product pages
  def features
    # Features page
  end
  
  def security
    # Security page
  end
  
  # Resource pages
  def documentation
    # Documentation page
  end
  
  def case_studies
    # Case studies page
  end
  
  def blog
    # Blog page
  end
  
  def support
    # Support page
  end
  
  # Company pages
  def about
    # About page
  end
  
  def careers
    # Careers page
  end
  
  def contact
    # Contact page
  end
  
  def partners
    # Partners page
  end
  
  # Legal pages
  def privacy_policy
    # Privacy policy page
  end
  
  def terms_of_service
    # Terms of service page
  end
  
  def cookie_policy
    # Cookie policy page
  end
  
  def lead_thank_you
    # Make the lead info available to the view - ensure it's a hash with symbol keys
    @lead_info = session[:lead_info]&.symbolize_keys || {}
    
    # If no lead info in session, create a default set to prevent errors
    if @lead_info.blank?
      @lead_info = {
        name: 'Guest',
        email: 'your email',
        company: 'your company',
        plan: 'free_trial',
        newsletter: false
      }
      
      # Log this issue for tracking
      Rails.logger.warn "Lead thank you page accessed without session data. Using defaults."
    else
      # Log the lead info for debugging in development
      Rails.logger.debug "Thank you page - Lead info: #{@lead_info.inspect}" if Rails.env.development?
      
      # Track conversion complete event with lead properties
      track_event('lead_conversion_complete', {
        lead_id: session[:lead_id],
        plan: @lead_info[:plan],
        funnel_stage: 'thankyou_page',
        conversion_completed: true
      })
    end
  end
end