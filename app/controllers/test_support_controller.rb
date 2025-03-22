class TestSupportController < ApplicationController
  # This controller is only available in the test environment
  before_action :ensure_test_environment
  
  # Setup session variables for testing
  def setup_session
    # Only permit specific keys that we know are safe for testing
    session_data = params.permit(
      :lead_id, 
      lead_info: [:name, :email, :company, :plan, :newsletter],
      quickbooks: [:realm_id, :access_token, :refresh_token, :token_type, :expires_at]
    ).to_h
    
    session_data.each do |key, value|
      session[key] = value
    end
    head :ok
  end
  
  private
  
  def ensure_test_environment
    unless Rails.env.test?
      render plain: "Access denied", status: :forbidden
    end
  end
end