class LeadsController < ApplicationController
  def create
    # In a real app, this would save to database and possibly trigger emails
    # For demo purposes, we'll just redirect to thank you page
    
    # Optional: Log the lead data for demo purposes
    Rails.logger.info "New Lead: #{lead_params.to_json}"
    
    # Store lead info in session to display on thank you page
    session[:lead_info] = {
      name: "#{lead_params[:first_name]} #{lead_params[:last_name]}",
      email: lead_params[:email],
      company: lead_params[:company],
      plan: lead_params[:plan]
    }
    
    # Redirect to thank you page
    redirect_to leads_thank_you_path
  end
  
  private
  
  def lead_params
    params.require(:lead).permit(:first_name, :last_name, :email, :company, :plan)
  end
end