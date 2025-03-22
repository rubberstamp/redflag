class LeadsController < ApplicationController
  # Protect the leads list with HTTP Basic Authentication in all environments
  http_basic_authenticate_with name: "admin", password: "redflag-admin", 
                               only: [:index, :admin_index]
  
  def index
    @leads = Lead.order(created_at: :desc).limit(100)
  end
  
  # Admin view with more details
  def admin_index
    @leads = Lead.order(created_at: :desc)
    render :index
  end
  
  def create
    # Create a Lead object
    @lead = Lead.new(lead_params)
    
    if @lead.save
      # Save the lead to the database
      Rails.logger.info "New Lead saved: #{@lead.id} - #{@lead.email}"
      
      # Store lead info in session to display on thank you page
      session[:lead_info] = {
        name: @lead.full_name,
        email: @lead.email,
        company: @lead.company,
        plan: @lead.plan,
        newsletter: @lead.newsletter
      }
      
      # Also store the lead ID in the session for reference
      session[:lead_id] = @lead.id
      
      # Track lead submission with PostHog
      track_event('lead_captured', {
        lead_id: @lead.id,
        email: @lead.email,
        company: @lead.company,
        plan: @lead.plan,
        newsletter: @lead.newsletter,
        conversion: true
      })
      
      # Identify the user with their lead info
      identify_user(@lead.id, {
        email: @lead.email,
        name: @lead.full_name,
        company: @lead.company,
        plan: @lead.plan,
        newsletter: @lead.newsletter,
        "$initial_referrer": request.referer
      })
      
      # Send welcome email to the lead
      LeadMailer.welcome_email(@lead).deliver_later
      
      # Send notification to admin
      LeadMailer.admin_notification(@lead).deliver_later
      
      # Redirect to thank you page - use the same domain for the redirect
      redirect_to leads_thank_you_path(host: request.host)
    else
      # If validation fails, set flash errors and redirect back to the form
      flash.now[:errors] = @lead.errors.full_messages
      # Re-render the home page with the form
      render template: "pages/home", status: :unprocessable_entity
    end
  end
  
  private
  
  def lead_params
    params.require(:lead).permit(:first_name, :last_name, :email, :company, :plan, :newsletter)
  end
end