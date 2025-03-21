class Quickbooks::ProfilesController < ApplicationController
  before_action :ensure_quickbooks_connected
  
  def show
    realm_id = session[:quickbooks]&.[]("realm_id")
    @profile = QuickbooksProfile.find_by(realm_id: realm_id)
    
    if @profile.nil?
      redirect_to root_path, alert: "QuickBooks profile not found"
      return
    end
    
    if @profile.token_expired?
      redirect_to quickbooks_refresh_token_path
      return
    end
    
    # Display the profile information
    render 'quickbooks/profiles/show'
  end
  
  private
  
  def ensure_quickbooks_connected
    realm_id = session[:quickbooks]&.[]("realm_id")
    
    unless realm_id.present?
      redirect_to root_path, alert: "Please connect to QuickBooks first"
      return
    end
  end
end