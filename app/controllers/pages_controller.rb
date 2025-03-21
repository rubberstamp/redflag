class PagesController < ApplicationController
  def home
  end
  
  def pricing
    # Static pricing page
  end
  
  def enterprise
    # Static enterprise page
  end
  
  def lead_thank_you
    # Make the lead info available to the view
    @lead_info = session[:lead_info]
    
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