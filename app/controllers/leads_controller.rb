class LeadsController < ApplicationController
  # Protect the leads list with HTTP Basic Authentication in all environments
  http_basic_authenticate_with name: ENV.fetch("ADMIN_USERNAME", "admin"),
                               password: ENV.fetch("ADMIN_PASSWORD", "admin"),
                               only: [:index, :admin_index]
  
  def index
    @leads = Lead.order(created_at: :desc).limit(100)
  end
  
  # Admin view with more details
  def admin_index
    @leads = Lead.order(created_at: :desc)
    render :index
  end
  
  # Initial lead capture - just email
  def initial_capture
    @lead = Lead.new(email: params[:email])
    
    if @lead.save
      # Save the lead to the database and store ID in session
      Rails.logger.info "Initial Lead captured: #{@lead.id} - #{@lead.email}"
      session[:lead_id] = @lead.id
      
      # Track initial lead capture with PostHog
      track_event('initial_lead_captured', {
        lead_id: @lead.id,
        email: @lead.email
      })
      
      # Return success JSON for AJAX form submission
      render json: { success: true, lead_id: @lead.id }
    else
      # Return validation errors for AJAX form
      render json: { success: false, errors: @lead.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # Complete lead capture - process the full lead info form
  def create
    # First check if we have an existing lead from the initial capture
    @lead = if session[:lead_id].present?
              Lead.find_by(id: session[:lead_id])
            end
    
    # If no existing lead, create a new one
    @lead ||= Lead.new
    
    # Update with the complete lead info
    @lead.assign_attributes(lead_params)
    
    if @lead.save
      # Save the lead to the database
      Rails.logger.info "Complete Lead info saved: #{@lead.id} - #{@lead.email}"
      
      # Store lead info in session to display on thank you page or CFO booking
      session[:lead_info] = {
        name: @lead.full_name,
        email: @lead.email,
        company: @lead.company,
        company_size: @lead.company_size,
        phone: @lead.phone,
        plan: @lead.plan,
        newsletter: @lead.newsletter
      }
      
      # Also ensure lead ID is in the session
      session[:lead_id] = @lead.id
      
      # Track complete lead submission with PostHog
      track_event('lead_completed', {
        lead_id: @lead.id,
        email: @lead.email,
        company: @lead.company,
        company_size: @lead.company_size,
        phone: @lead.phone, 
        plan: @lead.plan,
        newsletter: @lead.newsletter,
        conversion: true
      })
      
      # Identify the user with their lead info
      identify_user(@lead.id, {
        email: @lead.email,
        name: @lead.full_name,
        company: @lead.company,
        company_size: @lead.company_size,
        phone: @lead.phone,
        plan: @lead.plan,
        newsletter: @lead.newsletter,
        "$initial_referrer": request.referer
      })
      
      # Send welcome email to the lead
      LeadMailer.welcome_email(@lead).deliver_later
      
      # Send notification to admin
      LeadMailer.admin_notification(@lead).deliver_later
      
      # Determine where to send the user next
      if params[:skip_cfo_consultation] == "true"
        # User chose to skip the CFO consultation - go directly to report
        redirect_to_report_page
      else
        # Redirect to CFO consultation booking page
        redirect_to cfo_consultation_path
      end
    else
      # If validation fails, set flash errors and redirect back to the form
      flash.now[:errors] = @lead.errors.full_messages
      # Re-render the lead capture form with errors
      render "leads/capture", status: :unprocessable_entity
    end
  end
  
  # Show the CFO consultation booking form
  def cfo_consultation
    # Ensure we have a lead
    unless session[:lead_id].present?
      redirect_to root_path, alert: "Please start over with the analysis process."
      return
    end
    
    @lead = Lead.find_by(id: session[:lead_id])
    
    unless @lead&.complete_lead?
      redirect_to lead_capture_path, alert: "Please complete your information first."
      return
    end
  end
  
  # Process the CFO consultation booking or skip
  def process_consultation
    @lead = Lead.find_by(id: session[:lead_id])
    
    unless @lead
      redirect_to root_path, alert: "Please start over with the analysis process."
      return
    end
    
    # Update consultation preference
    @lead.update(cfo_consultation: params[:schedule_consultation] == "true")
    
    # Track the consultation choice
    track_event('cfo_consultation_choice', {
      lead_id: @lead.id,
      email: @lead.email,
      consultation_scheduled: @lead.cfo_consultation
    })
    
    # Redirect to the appropriate report page based on the analysis source
    redirect_to_report_page
  end
  
  # Show the full lead capture form
  def capture
    # Ensure we have an analysis in progress
    unless session[:analysis_session_id].present?
      redirect_to root_path, alert: "Please start an analysis first."
      return
    end
    
    # If we have a lead ID in session, pre-populate the form
    @lead = if session[:lead_id].present?
              Lead.find_by(id: session[:lead_id])
            else
              Lead.new
            end
  end
  
  private
  
  def lead_params
    params.require(:lead).permit(:first_name, :last_name, :email, :company, 
                                 :company_size, :phone, :plan, :newsletter)
  end
  
  def redirect_to_report_page
    # Determine which report page to show based on the analysis source
    if session[:analysis_session_id].blank?
      # No active analysis session - redirect to home
      redirect_to root_path
      return
    end
    
    if session[:import_source] == "csv"
      redirect_to report_imports_path
    else
      redirect_to quickbooks_analysis_report_path
    end
  end
end