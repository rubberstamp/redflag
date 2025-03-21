class LeadsController < ApplicationController
  def create
    # Create a Lead object to validate the data
    @lead = Lead.new(lead_params)
    
    if @lead.valid?
      # In a real app, this would save to database and possibly trigger emails
      # For demo purposes, we'll just redirect to thank you page
      
      # Optional: Log the lead data for demo purposes
      Rails.logger.info "New Lead: #{lead_params.to_json}"
      
      # Store lead info in session to display on thank you page
      session[:lead_info] = {
        name: "#{lead_params[:first_name]} #{lead_params[:last_name]}",
        email: lead_params[:email],
        company: lead_params[:company],
        plan: lead_params[:plan],
        newsletter: lead_params[:newsletter] == "1"
      }
      
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