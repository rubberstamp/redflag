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
    # If no lead info in session, redirect to home
    if session[:lead_info].blank?
      redirect_to root_path
      return
    end
    
    # Make the lead info available to the view
    @lead_info = session[:lead_info]
  end
end